package com.ones.api.application.users.lifecycle;

import java.time.Duration;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import jakarta.annotation.PreDestroy;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * Ejecuta en segundo plano, de una en una, la tarea diaria del ciclo de vida de cuentas:
 * primero cierra las cuentas vencidas y luego purga las cerradas. Un fallo en un paso no impide el otro.
 */
@Component
public class AccountLifecycleJob {

    private static final Logger log = LoggerFactory.getLogger(AccountLifecycleJob.class);

    public record Result(int closed, int purged) {
    }

    private final CloseExpiredAccountsUseCase close;
    private final PurgeClosedAccountsUseCase purge;
    private final ExecutorService executor;
    private final AtomicBoolean running = new AtomicBoolean(false);

    @Autowired
    public AccountLifecycleJob(CloseExpiredAccountsUseCase close, PurgeClosedAccountsUseCase purge) {
        this(close, purge, Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "account-lifecycle");
            t.setDaemon(true);
            return t;
        }));
    }

    AccountLifecycleJob(CloseExpiredAccountsUseCase close, PurgeClosedAccountsUseCase purge, ExecutorService executor) {
        this.close = close;
        this.purge = purge;
        this.executor = executor;
    }

    /** Lanza una corrida; devuelve false si ya hay una en curso (o el ejecutor no la acepta). */
    public boolean start() {
        if (!running.compareAndSet(false, true)) {
            return false;
        }
        try {
            executor.execute(this::run);
            return true;
        } catch (RuntimeException e) { // p. ej. RejectedExecutionException con el ejecutor cerrado
            running.set(false);
            log.error("[AccountLifecycle] no se pudo lanzar la corrida", e);
            return false;
        }
    }

    private void run() {
        try {
            int closed = 0;
            int purged = 0;
            try {
                closed = close.execute();
            } catch (Throwable t) {
                log.error("[AccountLifecycle] fallo al cerrar cuentas", t);
            }
            try {
                purged = purge.execute();
            } catch (Throwable t) {
                log.error("[AccountLifecycle] fallo al purgar cuentas", t);
            }
            log.info("[AccountLifecycle] closed={} purged={}", closed, purged);
        } finally {
            running.set(false);
        }
    }

    /** Espera a que termine la corrida actual (solo para tests). */
    boolean awaitIdle(Duration timeout) throws InterruptedException {
        long deadline = System.nanoTime() + timeout.toNanos();
        while (running.get()) {
            if (System.nanoTime() > deadline) {
                return false;
            }
            Thread.sleep(10);
        }
        return true;
    }

    @PreDestroy
    void shutdown() {
        executor.shutdown();
        try {
            if (!executor.awaitTermination(30, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
}
