package com.ones.api.adapters.inbound.rest.collections;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.lang.reflect.Method;

import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;

class CollectionsControllerPathBindingTest {

    @Test
    void removeMemberBindsTheEncodedMemberKeyPathSegment() throws Exception {
        Method remove = CollectionsController.class.getMethod(
                "removeMember", Authentication.class, String.class, String.class);

        DeleteMapping mapping = remove.getAnnotation(DeleteMapping.class);
        assertEquals("/{id}/members/{memberKey}", mapping.value()[0]);
        assertEquals("id", remove.getParameters()[1]
                .getAnnotation(PathVariable.class).value());
        assertEquals("memberKey", remove.getParameters()[2]
                .getAnnotation(PathVariable.class).value());
    }
}
