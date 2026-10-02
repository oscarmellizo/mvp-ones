package com.ones.api.adapters.inbound.rest.users;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.head;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.httpBasic;

import java.time.Clock;

import jakarta.servlet.http.HttpServletRequest;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.authentication.AuthenticationManagerResolver;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import com.ones.api.adapters.inbound.rest.internal.InternalAccountsController;
import com.ones.api.application.admin.AdminAccessService;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.users.AccountAccessService;
import com.ones.api.application.users.AccountMigrationService;
import com.ones.api.application.users.lifecycle.AccountLifecycleJob;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.configuration.SecurityConfig;

/** Cadenas de seguridad reales: la descarga es anónima y el disparo interno exige basic auth. */
@WebMvcTest(controllers = {AccountExportsController.class, InternalAccountsController.class})
@Import({SecurityConfig.class, AccountEndpointsSecurityTest.Beans.class})
@TestPropertySource(properties = {
        "ones.internal.basic.username=svc",
        "ones.internal.basic.password=secret",
        "ones.account.exports-bucket=exports"
})
class AccountEndpointsSecurityTest {

    @org.springframework.boot.test.context.TestConfiguration
    static class Beans {
        @org.springframework.context.annotation.Bean
        Clock clock() {
            return Clock.systemUTC();
        }
    }

    @Autowired MockMvc mvc;
    @MockBean UsersRepository usersRepository;
    @MockBean ObjectStoragePresigner presigner;
    @MockBean AccountLifecycleJob job;
    @MockBean AuthenticationManagerResolver<HttpServletRequest> jwtResolver;
    @MockBean AdminAccessService adminAccessService;
    @MockBean AccountAccessService accountAccessService;
    @MockBean AccountMigrationService accountMigrationService;

    @Test
    void exportDownload_isAnonymous_andUnknownRefIs404NotUnauthorized() throws Exception {
        mvc.perform(get("/v1/account-exports/u1.tok")).andExpect(status().isNotFound());
    }

    @Test
    void lifecycle_withoutCredentials_is401() throws Exception {
        mvc.perform(post("/internal/accounts/lifecycle")).andExpect(status().isUnauthorized());
    }

    @Test
    void lifecycle_withBasicAuth_returns202() throws Exception {
        when(job.start()).thenReturn(true);
        mvc.perform(post("/internal/accounts/lifecycle").with(httpBasic("svc", "secret")))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.started").value(true));
    }

    @Test
    void lifecycle_whileRunning_returns409() throws Exception {
        when(job.start()).thenReturn(false);
        mvc.perform(post("/internal/accounts/lifecycle").with(httpBasic("svc", "secret")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("RUN_IN_PROGRESS"));
    }
}
