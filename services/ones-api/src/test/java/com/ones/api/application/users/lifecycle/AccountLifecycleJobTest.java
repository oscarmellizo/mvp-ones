package com.ones.api.application.users.lifecycle;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;

class AccountLifecycleJobTest {

    private CloseExpiredAccountsUseCase close;
    private PurgeClosedAccountsUseCase purge;
    private ExecutorService executor;

    @BeforeEach
    void setUp() {
        close = mock(CloseExpiredAccountsUseCase.class);
        purge = mock(PurgeClosedAccountsUseCase.class);
        executor = Executors.newSingleThreadExecutor();
    }

    @AfterEach
    void tearDown() {
        executor.shutdownNow();
    }

    @Test
    void start_runsCloseThenPurge_once_whileRunning() throws Exception {
        CountDownLatch release = new CountDownLatch(1);
        when(close.execute()).thenAnswer(i -> {
            release.await();
            return 1;
        });
        when(purge.execute()).thenReturn(2);
        AccountLifecycleJob job = new AccountLifecycleJob(close, purge, executor);

        assertTrue(job.start());
        assertFalse(job.start()); // corrida en curso
        release.countDown();
        assertTrue(job.awaitIdle(Duration.ofSeconds(5)));

        InOrder order = inOrder(close, purge);
        order.verify(close).execute();
        order.verify(purge).execute();
        verify(close, times(1)).execute();
        assertTrue(job.start()); // terminó: se puede volver a lanzar
        assertTrue(job.awaitIdle(Duration.ofSeconds(5)));
    }

    @Test
    void closeFailure_stillRunsPurge() throws Exception {
        when(close.execute()).thenThrow(new RuntimeException("boom"));
        when(purge.execute()).thenReturn(3);
        AccountLifecycleJob job = new AccountLifecycleJob(close, purge, executor);

        assertTrue(job.start());
        assertTrue(job.awaitIdle(Duration.ofSeconds(5)));

        verify(purge).execute();
        assertTrue(job.start()); // running no quedó atascado
        assertTrue(job.awaitIdle(Duration.ofSeconds(5)));
    }

    @Test
    void purgeFailure_doesNotLeaveRunningStuck() throws Exception {
        when(close.execute()).thenReturn(1);
        when(purge.execute()).thenThrow(new IllegalStateException("boom"));
        AccountLifecycleJob job = new AccountLifecycleJob(close, purge, executor);

        assertTrue(job.start());
        assertTrue(job.awaitIdle(Duration.ofSeconds(5)));

        assertTrue(job.start());
        assertTrue(job.awaitIdle(Duration.ofSeconds(5)));
    }

    @Test
    void errorThrown_doesNotLeaveRunningStuck() throws Exception {
        when(close.execute()).thenThrow(new AssertionError("fatal"));
        when(purge.execute()).thenReturn(0);
        AccountLifecycleJob job = new AccountLifecycleJob(close, purge, executor);

        assertTrue(job.start());
        assertTrue(job.awaitIdle(Duration.ofSeconds(5)));
        assertTrue(job.start());
        assertTrue(job.awaitIdle(Duration.ofSeconds(5)));
    }

    @Test
    void rejectedExecution_releasesRunning() {
        executor.shutdown();
        AccountLifecycleJob job = new AccountLifecycleJob(close, purge, executor);

        assertFalse(job.start());
        assertFalse(job.start()); // sigue sin atascarse en true (rechaza por el ejecutor, no por running)
    }

    @Test
    void shutdown_stopsExecutor() {
        AccountLifecycleJob job = new AccountLifecycleJob(close, purge, executor);
        job.shutdown();
        assertTrue(executor.isShutdown());
    }
}
