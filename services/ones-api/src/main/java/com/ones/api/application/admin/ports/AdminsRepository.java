package com.ones.api.application.admin.ports;

public interface AdminsRepository {

    boolean isActiveAdmin(String email);
}
