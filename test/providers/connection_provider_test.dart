import 'package:flutter_test/flutter_test.dart';
import 'package:lbp_ssh/presentation/providers/connection_provider.dart';
import 'package:lbp_ssh/data/models/ssh_connection.dart';
import '../mocks/mocks.dart';

void main() {
  late MockConnectionRepository mockRepository;
  late ConnectionProvider connectionProvider;

  setUp(() {
    mockRepository = MockConnectionRepository();
    connectionProvider = ConnectionProvider(mockRepository);
    registerFallbackValues();
  });

  group('ConnectionProvider', () {
    group('initial state', () {
      test('Given new provider, When created, Then has empty connections list', () {
        expect(connectionProvider.connections, isEmpty);
        expect(connectionProvider.isLoading, false);
        expect(connectionProvider.error, isNull);
        expect(connectionProvider.searchQuery, '');
      });
    });

    group('loadConnections', () {
      test(
          'Given successful repository call, When loadConnections called, Then loads connections and clears error',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepository.getAllConnections()).thenReturn(connections);

        // Act (When)
        await connectionProvider.loadConnections();

        // Assert (Then)
        expect(connectionProvider.connections.length, 1);
        expect(connectionProvider.connections.first.name, 'Server 1');
        expect(connectionProvider.isLoading, false);
        expect(connectionProvider.error, isNull);
        verify(() => mockRepository.getAllConnections()).called(1);
      });

      test(
          'Given repository throws error, When loadConnections called, Then sets error and stops loading',
          () async {
        // Arrange (Given)
        when(() => mockRepository.getAllConnections())
            .thenThrow(Exception('Failed to load'));

        // Act (When)
        await connectionProvider.loadConnections();

        // Assert (Then)
        expect(connectionProvider.connections, isEmpty);
        expect(connectionProvider.isLoading, false);
        expect(connectionProvider.error, isNotNull);
        expect(connectionProvider.error, contains('加载连接失败'));
      });
    });

    group('addConnection', () {
      test(
          'Given valid connection, When addConnection called, Then saves to repository and reloads',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'new_conn',
          name: 'New Server',
          host: '192.168.1.100',
          port: 22,
          username: 'newuser',
          authType: AuthType.password,
        );
        when(() => mockRepository.saveConnection(connection))
            .thenAnswer((_) async {});
        when(() => mockRepository.getAllConnections()).thenReturn([connection]);

        // Act (When)
        await connectionProvider.addConnection(connection);

        // Assert (Then)
        verify(() => mockRepository.saveConnection(connection)).called(1);
        verify(() => mockRepository.getAllConnections()).called(1);
      });

      test(
          'Given repository throws error on add, When addConnection called, Then sets error and rethrows',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'new_conn',
          name: 'New Server',
          host: '192.168.1.100',
          port: 22,
          username: 'newuser',
          authType: AuthType.password,
        );
        when(() => mockRepository.saveConnection(connection))
            .thenThrow(Exception('Save failed'));

        // Act & Assert (When)
        expect(
          () => connectionProvider.addConnection(connection),
          throwsException,
        );
        expect(connectionProvider.error, isNotNull);
        expect(connectionProvider.error, contains('添加连接失败'));
      });
    });

    group('updateConnection', () {
      test(
          'Given valid connection, When updateConnection called, Then updates in repository and reloads',
          () async {
        // Arrange (Given)
        final connection = SshConnection(
          id: 'conn1',
          name: 'Updated Server',
          host: '192.168.1.1',
          port: 22,
          username: 'user1',
          authType: AuthType.password,
        );
        when(() => mockRepository.saveConnection(connection))
            .thenAnswer((_) async {});
        when(() => mockRepository.getAllConnections()).thenReturn([connection]);

        // Act (When)
        await connectionProvider.updateConnection(connection);

        // Assert (Then)
        verify(() => mockRepository.saveConnection(connection)).called(1);
        verify(() => mockRepository.getAllConnections()).called(1);
      });
    });

    group('deleteConnection', () {
      test(
          'Given connection id, When deleteConnection called, Then deletes from repository and reloads',
          () async {
        // Arrange (Given)
        const connectionId = 'conn1';
        when(() => mockRepository.deleteConnection(connectionId))
            .thenAnswer((_) async {});
        when(() => mockRepository.getAllConnections()).thenReturn([]);

        // Act (When)
        await connectionProvider.deleteConnection(connectionId);

        // Assert (Then)
        verify(() => mockRepository.deleteConnection(connectionId)).called(1);
        verify(() => mockRepository.getAllConnections()).called(1);
      });

      test(
          'Given repository throws error on delete, When deleteConnection called, Then sets error',
          () async {
        // Arrange (Given)
        const connectionId = 'conn1';
        when(() => mockRepository.deleteConnection(connectionId))
            .thenThrow(Exception('Delete failed'));

        // Act & Assert (When)
        expect(
          () => connectionProvider.deleteConnection(connectionId),
          throwsException,
        );
        expect(connectionProvider.error, isNotNull);
        expect(connectionProvider.error, contains('删除连接失败'));
      });
    });

    group('getConnectionById', () {
      test(
          'Given existing connection id, When getConnectionById called, Then returns connection',
          () {
        // Arrange (Given)
        const connectionId = 'conn1';
        final connection = SshConnection(
          id: connectionId,
          name: 'Server 1',
          host: '192.168.1.1',
          port: 22,
          username: 'user1',
          authType: AuthType.password,
        );
        when(() => mockRepository.getConnectionById(connectionId))
            .thenReturn(connection);

        // Act (When)
        final result = connectionProvider.getConnectionById(connectionId);

        // Assert (Then)
        expect(result, isNotNull);
        expect(result!.id, connectionId);
        verify(() => mockRepository.getConnectionById(connectionId)).called(1);
      });

      test(
          'Given non-existing connection id, When getConnectionById called, Then returns null',
          () {
        // Arrange (Given)
        const connectionId = 'nonexistent';
        when(() => mockRepository.getConnectionById(connectionId))
            .thenReturn(null);

        // Act (When)
        final result = connectionProvider.getConnectionById(connectionId);

        // Assert (Then)
        expect(result, isNull);
      });
    });

    group('search and filter', () {
      test(
          'Given search query, When setSearchQuery called, Then updates search query and notifies listeners',
          () {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Production Server',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
          SshConnection(
            id: 'conn2',
            name: 'Development Server',
            host: '192.168.1.2',
            port: 22,
            username: 'user2',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepository.getAllConnections()).thenReturn(connections);

        // Act (When)
        connectionProvider.setSearchQuery('prod');

        // Assert (Then)
        expect(connectionProvider.searchQuery, 'prod');
      });

      test(
          'Given empty search query, When filteredConnections accessed, Then returns all connections',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepository.getAllConnections()).thenReturn(connections);

        // Act (When) - Load connections first
        await connectionProvider.loadConnections();

        // Assert (Then)
        expect(connectionProvider.filteredConnections.length, 1);
      });

      test(
          'Given search query, When filteredConnections accessed with empty connections, Then returns empty list',
          () {
        // Arrange (Given) - Set search query with no connections loaded
        connectionProvider.setSearchQuery('prod');

        // Assert (Then) - Should return empty when no connections
        expect(connectionProvider.filteredConnections, isEmpty);
      });

      test(
          'Given clearSearch called, When called, Then clears search query',
          () {
        // Act (When)
        connectionProvider.setSearchQuery('test');
        connectionProvider.clearSearch();

        // Assert (Then)
        expect(connectionProvider.searchQuery, '');
      });

      test(
          'Given search query matching host, When filteredConnections accessed, Then returns matching connections',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Production Server',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
          SshConnection(
            id: 'conn2',
            name: 'Development Server',
            host: '192.168.2.2',
            port: 22,
            username: 'user2',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepository.getAllConnections()).thenReturn(connections);
        await connectionProvider.loadConnections();

        // Act (When)
        connectionProvider.setSearchQuery('192.168.1');

        // Assert (Then)
        expect(connectionProvider.filteredConnections.length, 1);
        expect(connectionProvider.filteredConnections.first.name, 'Production Server');
      });

      test(
          'Given search query matching username, When filteredConnections accessed, Then returns matching connections',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'admin',
            authType: AuthType.password,
          ),
          SshConnection(
            id: 'conn2',
            name: 'Server 2',
            host: '192.168.2.2',
            port: 22,
            username: 'user',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepository.getAllConnections()).thenReturn(connections);
        await connectionProvider.loadConnections();

        // Act (When)
        connectionProvider.setSearchQuery('admin');

        // Assert (Then)
        expect(connectionProvider.filteredConnections.length, 1);
        expect(connectionProvider.filteredConnections.first.username, 'admin');
      });

      test(
          'Given case insensitive search, When filteredConnections accessed, Then returns matching connections',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Production Server',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepository.getAllConnections()).thenReturn(connections);
        await connectionProvider.loadConnections();

        // Act (When)
        connectionProvider.setSearchQuery('PRODUCTION');

        // Assert (Then)
        expect(connectionProvider.filteredConnections.length, 1);
      });

      test(
          'Given search query with no match, When filteredConnections accessed, Then returns empty list',
          () async {
        // Arrange (Given)
        final connections = [
          SshConnection(
            id: 'conn1',
            name: 'Server 1',
            host: '192.168.1.1',
            port: 22,
            username: 'user1',
            authType: AuthType.password,
          ),
        ];
        when(() => mockRepository.getAllConnections()).thenReturn(connections);
        await connectionProvider.loadConnections();

        // Act (When)
        connectionProvider.setSearchQuery('nonexistent');

        // Assert (Then)
        expect(connectionProvider.filteredConnections, isEmpty);
      });
    });

    group('duplicate connection handling', () {
      test(
          'Given duplicate connection name, When adding, Then allows duplicate names',
          () async {
        // Arrange (Given)
        final connection1 = SshConnection(
          id: 'conn1',
          name: 'Server',
          host: '192.168.1.1',
          port: 22,
          username: 'user1',
          authType: AuthType.password,
        );
        final connection2 = SshConnection(
          id: 'conn2',
          name: 'Server',
          host: '192.168.1.2',
          port: 22,
          username: 'user2',
          authType: AuthType.password,
        );
        when(() => mockRepository.saveConnection(connection1))
            .thenAnswer((_) async {});
        when(() => mockRepository.getAllConnections()).thenReturn([connection1]);

        await connectionProvider.addConnection(connection1);

        when(() => mockRepository.saveConnection(connection2))
            .thenAnswer((_) async {});
        when(() => mockRepository.getAllConnections()).thenReturn([connection1, connection2]);

        // Act (When)
        await connectionProvider.addConnection(connection2);

        // Assert (Then)
        verify(() => mockRepository.saveConnection(connection2)).called(1);
      });
    });
  });
}
