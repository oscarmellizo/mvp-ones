import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/collections/domain/collection.dart';
import 'package:ones_app/features/collections/presentation/widgets/collection_member_filter_sheet.dart';

void main() {
  testWidgets('member filter pages accepted members and omits pending invites',
      (tester) async {
    final requestedCursors = <String?>[];
    final requestedLimits = <int>[];

    Future<CollectionMembersPage> loadPage(String? cursor, int limit) async {
      requestedCursors.add(cursor);
      requestedLimits.add(limit);
      if (cursor == null) {
        return const CollectionMembersPage(
          items: [
            CollectionMember(
              memberKey: 'USER#owner',
              userId: 'owner',
              email: 'owner@example.com',
              status: 'ACCEPTED',
              invitedByUserId: null,
            ),
            CollectionMember(
              memberKey: 'USER#member-1',
              userId: 'member-1',
              email: 'member1@example.com',
              status: 'ACCEPTED',
              invitedByUserId: 'owner',
            ),
            CollectionMember(
              memberKey: 'EMAIL#pending',
              userId: null,
              email: 'pending@example.com',
              status: 'PENDING',
              invitedByUserId: 'owner',
            ),
          ],
          nextToken: 'page-2',
        );
      }
      return const CollectionMembersPage(
        items: [
          CollectionMember(
            memberKey: 'USER#member-2',
            userId: 'member-2',
            email: 'member2@example.com',
            status: 'ACCEPTED',
            invitedByUserId: 'owner',
          ),
        ],
        nextToken: null,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionMemberFilterSheet(
            collectionOwnerId: 'owner',
            currentUserId: 'owner',
            initialSelectedIds: const {'member-1'},
            loadMembersPage: loadPage,
            title: 'Filtrar por miembros',
            ownerLabel: 'Propietario',
            youLabel: 'Tú',
            emptyLabel: 'Sin miembros',
            errorLabel: 'Error',
            retryLabel: 'Reintentar',
            loadMoreLabel: 'Cargar más',
            selectionLimitLabel: 'Hasta 100',
            clearLabel: 'Limpiar',
            cancelLabel: 'Cancelar',
            applyLabel: 'Aplicar',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tú · Propietario'), findsOneWidget);
    expect(find.text('member1@example.com'), findsOneWidget);
    expect(find.text('pending@example.com'), findsNothing);
    expect(requestedCursors, [null]);
    expect(requestedLimits, [50]);

    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();

    expect(find.text('member2@example.com'), findsOneWidget);
    expect(requestedCursors, [null, 'page-2']);
    expect(requestedLimits, [50, 50]);
  });
}
