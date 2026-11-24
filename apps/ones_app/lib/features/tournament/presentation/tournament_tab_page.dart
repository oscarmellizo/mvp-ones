import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/translations_service.dart';
import '../adapters/api/tournament_api_repository.dart';

class TournamentTabPage extends StatefulWidget {
  final String eventId;

  const TournamentTabPage({super.key, required this.eventId});

  @override
  State<TournamentTabPage> createState() => _TournamentTabPageState();
}

class _TournamentTabPageState extends State<TournamentTabPage> {
  final List<TextEditingController> _teamNames =
      List.generate(4, (_) => TextEditingController());
  final Map<String, TextEditingController> _homeScores = {};
  final Map<String, TextEditingController> _awayScores = {};
  final Map<String, Future<String>> _logoUrls = {};
  final Map<String, TextEditingController> _actualHomeScores = {};
  final Map<String, TextEditingController> _actualAwayScores = {};
  final Map<String, String> _penaltyWinners = {};
  final Set<String> _editingResults = {};
  final Map<String, TextEditingController> _prompts = {};

  TournamentApiRepository? _api;
  Map<String, dynamic>? _view;
  List<Map<String, dynamic>> _members = const [];
  final Set<String> _delegates = {};
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _initializedFields = false;
  bool _membersLoadError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = context.read<TournamentApiRepository>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in [
      ..._teamNames,
      ..._homeScores.values,
      ..._awayScores.values,
      ..._actualHomeScores.values,
      ..._actualAwayScores.values,
      ..._prompts.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_api == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _membersLoadError = false;
    });
    try {
      final value = await _api!.get(widget.eventId);
      final tournament = Map<String, dynamic>.from(value['tournament'] as Map);
      final teams = (tournament['teams'] as List? ?? const [])
          .whereType<Map>()
          .map((team) => Map<String, dynamic>.from(team))
          .toList();
      if (!_initializedFields) {
        for (var i = 0; i < 4; i++) {
          if (i < teams.length) _teamNames[i].text = teams[i]['name'] ?? '';
        }
        _initializedFields = true;
      }
      final prediction = value['myPrediction'] is Map
          ? Map<String, dynamic>.from(value['myPrediction'] as Map)
          : <String, dynamic>{};
      final groupScores = prediction['roundRobinScores'] is Map
          ? Map<String, dynamic>.from(prediction['roundRobinScores'] as Map)
          : <String, dynamic>{};
      for (final entry in groupScores.entries) {
        if (entry.value is! Map) continue;
        final score = Map<String, dynamic>.from(entry.value as Map);
        _controller(_homeScores, entry.key).text =
            score['homeGoals']?.toString() ?? '';
        _controller(_awayScores, entry.key).text =
            score['awayGoals']?.toString() ?? '';
      }
      _setScoreField('final', prediction['finalScore']);
      _setScoreField('third-place', prediction['thirdPlaceScore']);
      final matches = (tournament['matches'] as List? ?? const [])
          .whereType<Map>()
          .map((match) => Map<String, dynamic>.from(match))
          .toList();
      for (final match in matches) {
        final id = match['id'] as String;
        if (match['homeGoals'] != null) {
          _controller(_actualHomeScores, id).text =
              match['homeGoals'].toString();
        }
        if (match['awayGoals'] != null) {
          _controller(_actualAwayScores, id).text =
              match['awayGoals'].toString();
        }
      }
      if (value['owner'] == true) {
        try {
          _members = await _api!.acceptedMembers(widget.eventId);
          _membersLoadError = false;
        } on DioException {
          // Loading delegates is optional; it must not block tournament setup.
          _members = const [];
          _membersLoadError = true;
        }
        _delegates
          ..clear()
          ..addAll(
              List<String>.from(tournament['delegateUserIds'] ?? const []));
      }
      if (!mounted) return;
      setState(() {
        _view = value;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _loadErrorMessage(e);
        _loading = false;
      });
    }
  }

  String _loadErrorMessage(Object error) {
    if (error is! DioException) return error.toString();

    final body = error.response?.data;
    final message = body is Map ? body['message']?.toString() : null;
    final status = error.response?.statusCode;
    final request = '${error.requestOptions.method} ${error.requestOptions.path}';
    if (message != null && message.isNotEmpty) {
      return '$message\n$request (HTTP ${status ?? 'sin respuesta'})';
    }
    return '$request (HTTP ${status ?? 'sin respuesta'})';
  }

  String _actionError(Object error) => _loadErrorMessage(error);

  void _setScoreField(String id, dynamic data) {
    if (data is! Map) return;
    final score = Map<String, dynamic>.from(data);
    _controller(_homeScores, id).text = score['homeGoals']?.toString() ?? '';
    _controller(_awayScores, id).text = score['awayGoals']?.toString() ?? '';
  }

  TextEditingController _controller(
    Map<String, TextEditingController> map,
    String key,
  ) =>
      map.putIfAbsent(key, TextEditingController.new);

  Map<String, dynamic> _scores() {
    final result = <String, dynamic>{};
    final roundRobinIds = _matches
        .where((match) => match['phase'] == 'ROUND_ROBIN')
        .map((match) => match['id'] as String)
        .toSet();
    for (final entry in _homeScores.entries) {
      if (!roundRobinIds.contains(entry.key)) continue;
      final home = int.tryParse(entry.value.text);
      final away = int.tryParse(_awayScores[entry.key]?.text ?? '');
      if (home != null && away != null) {
        result[entry.key] = {'homeGoals': home, 'awayGoals': away};
      }
    }
    return result;
  }

  Map<String, dynamic>? _scoreFor(String id) {
    final home = int.tryParse(_homeScores[id]?.text ?? '');
    final away = int.tryParse(_awayScores[id]?.text ?? '');
    if (home == null || away == null) return null;
    return {'homeGoals': home, 'awayGoals': away};
  }

  List<Map<String, dynamic>> _projectedTable(
    List<Map<String, dynamic>> teams,
    List<Map<String, dynamic>> matches,
  ) {
    final rows = <String, Map<String, dynamic>>{};
    for (var i = 0; i < teams.length; i++) {
      final team = teams[i];
      rows[team['id'] as String] = {
        'id': team['id'],
        'name': team['name'],
        'seed': i,
        'played': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'gf': 0,
        'ga': 0,
        'points': 0,
      };
    }
    for (final match in matches.where((m) => m['phase'] == 'ROUND_ROBIN')) {
      final id = match['id'] as String;
      final score = _scoreFor(id);
      if (score == null) continue;
      final home = rows[match['homeTeamId']];
      final away = rows[match['awayTeamId']];
      if (home == null || away == null) continue;
      final hg = score['homeGoals'] as int;
      final ag = score['awayGoals'] as int;
      home['played']++;
      away['played']++;
      home['gf'] += hg;
      home['ga'] += ag;
      away['gf'] += ag;
      away['ga'] += hg;
      if (hg > ag) {
        home['wins']++;
        away['losses']++;
        home['points'] += 3;
      } else if (ag > hg) {
        away['wins']++;
        home['losses']++;
        away['points'] += 3;
      } else {
        home['draws']++;
        away['draws']++;
        home['points']++;
        away['points']++;
      }
    }
    final result = rows.values.toList()
      ..sort((a, b) {
        final p = (b['points'] as int).compareTo(a['points'] as int);
        if (p != 0) return p;
        final gdA = (a['gf'] as int) - (a['ga'] as int);
        final gdB = (b['gf'] as int) - (b['ga'] as int);
        final gd = gdB.compareTo(gdA);
        if (gd != 0) return gd;
        final gf = (b['gf'] as int).compareTo(a['gf'] as int);
        return gf != 0 ? gf : (a['seed'] as int).compareTo(b['seed'] as int);
      });
    return result;
  }

  Future<void> _saveSetup() async {
    final current = _tournament;
    if (current == null) return;
    final existing = (current['teams'] as List? ?? const [])
        .whereType<Map>()
        .map((team) => Map<String, dynamic>.from(team))
        .toList();
    setState(() => _busy = true);
    try {
      final teams = List.generate(
          4,
          (i) => {
                if (i < existing.length) 'id': existing[i]['id'],
                'name': _teamNames[i].text.trim(),
                if (i < existing.length && existing[i]['logoKey'] != null)
                  'logoKey': existing[i]['logoKey'],
                if (i < existing.length && existing[i]['members'] != null)
                  'members': existing[i]['members'],
              });
      await _api!.saveSetup(widget.eventId, teams);
      await _load();
      _toast('Equipos guardados. Ya puedes abrir los pronósticos.');
    } catch (e) {
      _toast('No se pudo guardar la configuración: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickLogo(String teamId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    setState(() => _busy = true);
    try {
      final preview = await _api!
          .uploadLogo(widget.eventId, teamId, result.files.single.bytes!);
      await _previewLogo(teamId, preview);
    } catch (e) {
      _toast('No se pudo cargar el logo: ${_actionError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateLogo(String teamId) async {
    final promptController = TextEditingController();
    final prompt = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar logo con IA'),
        content: TextField(
          controller: promptController,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Describe el estilo, colores o símbolo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, promptController.text),
            child: const Text('Generar'),
          ),
        ],
      ),
    );
    promptController.dispose();
    if (prompt == null || prompt.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final preview =
          await _api!.generateLogo(widget.eventId, teamId, prompt.trim());
      if (mounted) await _previewLogo(teamId, preview);
    } catch (e) {
      _toast('No se pudo generar el logo: ${_actionError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewLogo(
    String teamId,
    Map<String, dynamic> preview,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vista previa del logo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(preview['previewUrl'] as String,
                width: 180, height: 180),
            const SizedBox(height: 8),
            const Text('La imagen se normalizará a 512 × 512 píxeles.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usar logo'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await _api!.acceptLogo(
        widget.eventId,
        teamId,
        preview['previewKey'] as String,
      );
      _logoUrls.remove(teamId);
      await _load();
      _toast('Logo aplicado al equipo.');
    }
  }

  Future<void> _savePrediction(List<Map<String, dynamic>> teams) async {
    final prediction = _view?['myPrediction'] as Map?;
    final oldProjection = (_view?['myProjection'] as Map?) ?? const {};
    final projected = _projectedTable(teams, _matches);
    final finalHome = projected.isNotEmpty ? projected.first['id'] : null;
    final finalAway = projected.length > 1 ? projected[1]['id'] : null;
    final thirdHome = projected.length > 2 ? projected[2]['id'] : null;
    final thirdAway = projected.length > 3 ? projected[3]['id'] : null;
    final projectionChanged = oldProjection['finalHomeTeamId'] != finalHome ||
        oldProjection['finalAwayTeamId'] != finalAway ||
        oldProjection['thirdHomeTeamId'] != thirdHome ||
        oldProjection['thirdAwayTeamId'] != thirdAway;
    final hasKnockoutScores = _scoreFor('final') != null ||
        _scoreFor('third-place') != null ||
        (prediction?['finalScore'] != null) ||
        (prediction?['thirdPlaceScore'] != null);
    if (projectionChanged && hasKnockoutScores) {
      final decision = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambian los clasificados'),
          content: const Text(
            'Al cambiar la proyección se borrarán los marcadores de final y tercer puesto. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'keep'),
              child: const Text('Conservar marcadores'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'clear'),
              child: const Text('Borrar marcadores'),
            ),
          ],
        ),
      );
      if (decision == null) return;
      if (decision == 'clear') {
        _homeScores['final']?.clear();
        _awayScores['final']?.clear();
        _homeScores['third-place']?.clear();
        _awayScores['third-place']?.clear();
      }
    }
    setState(() => _busy = true);
    try {
      await _api!.savePredictions(
        widget.eventId,
        roundRobinScores: _scores(),
        finalScore: _scoreFor('final'),
        thirdPlaceScore: _scoreFor('third-place'),
      );
      await _load();
      _toast('Pronósticos guardados.');
    } catch (e) {
      _toast('No se pudieron guardar los pronósticos: ${_actionError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startPredictions() async {
    setState(() => _busy = true);
    try {
      await _api!.startPredictions(widget.eventId);
      await _load();
    } catch (e) {
      _toast('No se pudo iniciar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closePredictions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar pronósticos'),
        content: const Text(
          'Las personas ya no podrán editar sus marcadores. ¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _api!.closePredictions(widget.eventId);
      await _load();
    } catch (e) {
      _toast('No se pudo cerrar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleDelegate(String userId, bool value) async {
    setState(() {
      if (value) {
        _delegates.add(userId);
      } else {
        _delegates.remove(userId);
      }
    });
    try {
      await _api!.setDelegates(widget.eventId, _delegates.toList());
      await _load();
    } catch (e) {
      _toast('No se pudieron actualizar los delegados: $e');
    }
  }

  Future<void> _startMatch(String matchId) async {
    try {
      await _api!.startMatch(widget.eventId, matchId);
      await _load();
    } catch (e) {
      _toast('No se pudo iniciar el partido: $e');
    }
  }

  Future<void> _finishMatch(Map<String, dynamic> match) async {
    final id = match['id'] as String;
    final home = int.tryParse(_actualHomeScores[id]?.text ?? '');
    final away = int.tryParse(_actualAwayScores[id]?.text ?? '');
    if (home == null || away == null) {
      _toast('Ingresa los dos marcadores.');
      return;
    }
    var confirmKnockoutReset = false;
    final hasKnockoutResults = _matches.any((item) =>
        item['phase'] != 'ROUND_ROBIN' && item['status'] != 'PENDING');
    if (match['status'] == 'FINISHED' &&
        match['phase'] == 'ROUND_ROBIN' &&
        hasKnockoutResults) {
      confirmKnockoutReset = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Corregir resultado'),
              content: const Text(
                'Se borraran los resultados de final y tercer puesto, se recalcularan los cruces y se reabriran los pronosticos.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmar correccion'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmKnockoutReset) return;
    }
    try {
      await _api!.finishMatch(
        widget.eventId,
        id,
        homeGoals: home,
        awayGoals: away,
        penaltyWinnerTeamId:
            match['phase'] == 'ROUND_ROBIN' ? null : _penaltyWinners[id],
        confirmKnockoutReset: confirmKnockoutReset,
      );
      _editingResults.remove(id);
      await _load();
    } catch (e) {
      _toast('No se pudo guardar el resultado: $e');
    }
  }

  void _toast(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _t(String key, String fallback) =>
      context.read<TranslationsService>().translate(key, fallback: fallback);

  Map<String, dynamic>? get _tournament => _view?['tournament'] is Map
      ? Map<String, dynamic>.from(_view!['tournament'] as Map)
      : null;

  List<Map<String, dynamic>> get _teams =>
      (_tournament?['teams'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  List<Map<String, dynamic>> get _matches =>
      (_tournament?['matches'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final state = _tournament;
    if (state == null) {
      return const Center(child: Text('Torneo no disponible.'));
    }
    final manager = _view?['owner'] == true || _view?['delegate'] == true;
    final owner = _view?['owner'] == true;
    final groupStatus =
        (state['groupPredictionPeriod'] as Map?)?['status'] ?? 'NOT_STARTED';
    final teams = _teams;
    final matches = _matches;
    final projected = _projectedTable(teams, matches);
    final scroll = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading(
                'Torneo 4 Equipos',
                'Pronósticos, posiciones y resultados en un solo lugar.',
              ),
              if (manager) ...[
                _setupCard(teams, owner),
                if (owner) _delegatesCard(),
                _managerControls(groupStatus.toString(), state),
                if (_needsTieBreak(state)) _tieBreakCard(state),
                _matchesCard(matches, manager),
              ],
              if (teams.length == 4) ...[
                _standingsCard(_view?['standings'], projected),
                _predictionCard(
                  teams,
                  matches,
                  projected,
                  groupStatus.toString() == 'OPEN',
                ),
                if (_view?['forecastsRevealed'] == true)
                  _leaderboardCard(_view?['leaderboard']),
              ],
            ],
          ),
        ),
      ),
    );
    return Stack(
      children: [
        RefreshIndicator(onRefresh: _load, child: scroll),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _heading(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('tournament.title', title),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(_t('tournament.subtitle', subtitle)),
          ],
        ),
      );

  Widget _setupCard(List<Map<String, dynamic>> teams, bool owner) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_t('tournament.teams', 'Configuración de equipos'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              for (var i = 0; i < 4; i++)
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _teamLogo(teams, i),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _teamNames[i],
                        enabled: owner && teams.every((t) => t['id'] != null),
                        decoration: InputDecoration(
                          labelText:
                              '${_t('tournament.team', 'Equipo')} ${i + 1}',
                        ),
                      ),
                    ),
                    if (i < teams.length && teams[i]['id'] != null)
                      PopupMenuButton<String>(
                        tooltip: 'Logo del equipo',
                        onSelected: (action) {
                          final id = teams[i]['id'] as String;
                          if (action == 'upload') _pickLogo(id);
                          if (action == 'generate') _generateLogo(id);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'upload',
                              child: Text(_t(
                                  'tournament.upload_logo', 'Subir imagen'))),
                          PopupMenuItem(
                              value: 'generate',
                              child: Text(_t('tournament.generate_logo',
                                  'Generar con IA'))),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.add_a_photo_outlined),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              if (owner)
                FilledButton(
                  onPressed: _busy ? null : _saveSetup,
                  child: Text(_t('tournament.save_teams', 'Guardar equipos')),
                ),
            ],
          ),
        ),
      );

  Widget _teamLogo(List<Map<String, dynamic>> teams, int index) {
    if (index >= teams.length || teams[index]['id'] == null) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Icon(Icons.shield_outlined),
      );
    }
    final teamId = teams[index]['id'] as String;
    if (teams[index]['logoKey'] == null || _api == null) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Icon(Icons.shield_outlined),
      );
    }

    final url = _logoUrls.putIfAbsent(
      teamId,
      () => _api!.logoUrl(widget.eventId, teamId),
    );
    return FutureBuilder<String>(
      future: url,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.shield_outlined),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            snapshot.data!,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined),
          ),
        );
      },
    );
  }

  Widget _delegatesCard() => Card(
        child: ExpansionTile(
          title: Text(_t('tournament.delegates', 'Delegados'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            _membersLoadError
                ? 'No se pudieron cargar los invitados; puedes configurar el torneo y volver a intentarlo más tarde.'
                : _t('tournament.accepted_members_only',
                    'Solo personas que ya aceptaron el evento.'),
          ),
          children: [
            for (final member in _members)
              if (member['userId'] != null)
                CheckboxListTile(
                  value: _delegates.contains(member['userId']),
                  title: Text((member['displayName'] ??
                          member['name'] ??
                          member['email'] ??
                          member['userId'])
                      .toString()),
                  onChanged: (value) => _toggleDelegate(
                      member['userId'].toString(), value ?? false),
                ),
          ],
        ),
      );

  Widget _managerControls(String status, Map<String, dynamic> state) {
    final configured = state['configured'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text('Pronósticos: $status')),
            if (status != 'OPEN')
              FilledButton.icon(
                onPressed: _busy || !configured ? null : _startPredictions,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar pronósticos'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _closePredictions,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Cerrar pronósticos'),
              ),
          ],
        ),
      ),
    );
  }

  bool _needsTieBreak(Map<String, dynamic> state) {
    final groupMatches = _matches.where((m) => m['phase'] == 'ROUND_ROBIN');
    if (groupMatches.isEmpty ||
        groupMatches.any((m) => m['status'] != 'FINISHED')) {
      return false;
    }
    final rows =
        (_view?['standings'] as List? ?? const []).whereType<Map>().toList();
    for (var i = 0; i + 1 < rows.length; i++) {
      final first = rows[i];
      final second = rows[i + 1];
      if (first['points'] == second['points'] &&
          first['goalDifference'] == second['goalDifference'] &&
          first['goalsFor'] == second['goalsFor']) {
        return true;
      }
    }
    return false;
  }

  Widget _tieBreakCard(Map<String, dynamic> state) => Card(
        child: ListTile(
          leading: const Icon(Icons.reorder),
          title: const Text('Desempate manual requerido'),
          subtitle: const Text('El orden quedará auditado para este torneo.'),
          trailing: FilledButton(
            onPressed: _busy ? null : () => _resolveTieBreak(state),
            child: const Text('Resolver'),
          ),
        ),
      );

  Future<void> _resolveTieBreak(Map<String, dynamic> state) async {
    final rows = (_view?['standings'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final savedOrder = List<String>.from(state['manualTieOrder'] ?? const []);
    final order = savedOrder.length == 4
        ? savedOrder
        : rows.map((row) => row['teamId'].toString()).toList();
    final reasonController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Resolver desempate'),
          content: SizedBox(
            width: 460,
            height: 380,
            child: Column(
              children: [
                const Text(
                    'Arrastra para definir el orden final de los equipos.'),
                Expanded(
                  child: ReorderableListView(
                    onReorderItem: (oldIndex, newIndex) {
                      setDialogState(() {
                        final item = order.removeAt(oldIndex);
                        order.insert(newIndex, item);
                      });
                    },
                    children: [
                      for (final id in order)
                        ListTile(
                          key: ValueKey(id),
                          leading: const Icon(Icons.drag_handle),
                          title: Text(_teamName(id)),
                        ),
                    ],
                  ),
                ),
                TextField(
                  controller: reasonController,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del desempate',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'order': List<String>.from(order),
                'reason': reasonController.text.trim(),
              }),
              child: const Text('Guardar orden'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (result == null || (result['reason'] as String).isEmpty) return;
    try {
      await _api!.setTieBreakOrder(
        widget.eventId,
        teamIds: List<String>.from(result['order'] as List),
        reason: result['reason'] as String,
      );
      await _load();
    } catch (e) {
      _toast('No se pudo guardar el desempate: $e');
    }
  }

  Widget _matchesCard(List<Map<String, dynamic>> matches, bool manager) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  _t('tournament.actual_matches',
                      'Partidos y resultados reales'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18)),
              for (final match in matches) _matchRow(match, manager),
            ],
          ),
        ),
      );

  Widget _matchRow(Map<String, dynamic> match, bool manager) {
    final id = match['id'] as String;
    final home = _teamName(match['homeTeamId']);
    final away = _teamName(match['awayTeamId']);
    final status = match['status']?.toString() ?? 'PENDING';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          SizedBox(width: 140, child: Text('$home vs $away')),
          TextField(
            controller: _controller(_actualHomeScores, id),
            enabled: manager &&
                (status == 'IN_PROGRESS' || _editingResults.contains(id)),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration:
                const InputDecoration(labelText: 'Local', isDense: true),
            textAlign: TextAlign.center,
            maxLength: 2,
          ),
          const Text('-'),
          TextField(
            controller: _controller(_actualAwayScores, id),
            enabled: manager &&
                (status == 'IN_PROGRESS' || _editingResults.contains(id)),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration:
                const InputDecoration(labelText: 'Visita', isDense: true),
            textAlign: TextAlign.center,
            maxLength: 2,
          ),
          if (manager && status == 'PENDING' && home != 'Por definir')
            OutlinedButton(
              onPressed: _busy ? null : () => _startMatch(id),
              child: const Text('Iniciar'),
            ),
          if (manager &&
              (status == 'IN_PROGRESS' || _editingResults.contains(id)))
            FilledButton(
              onPressed: _busy ? null : () => _finishMatch(match),
              child: Text(
                  status == 'FINISHED' ? 'Guardar corrección' : 'Finalizar'),
            ),
          if (status == 'IN_PROGRESS' &&
              match['phase'] != 'ROUND_ROBIN' &&
              _actualHomeScores[id]?.text == _actualAwayScores[id]?.text &&
              _actualHomeScores[id]?.text.isNotEmpty == true)
            DropdownButton<String>(
              value: _penaltyWinners[id],
              hint: const Text('Ganador penales'),
              items: [
                if (match['homeTeamId'] != null)
                  DropdownMenuItem<String>(
                    value: match['homeTeamId'] as String,
                    child: Text(home),
                  ),
                if (match['awayTeamId'] != null)
                  DropdownMenuItem<String>(
                    value: match['awayTeamId'] as String,
                    child: Text(away),
                  ),
              ],
              onChanged: (value) => setState(() {
                if (value == null) {
                  _penaltyWinners.remove(id);
                } else {
                  _penaltyWinners[id] = value;
                }
              }),
            ),
          if (status == 'FINISHED') ...[
            Text('${match['homeGoals']} - ${match['awayGoals']}'),
            if (manager && !_editingResults.contains(id))
              TextButton(
                onPressed: () => setState(() {
                  _editingResults.add(id);
                  _actualHomeScores[id]?.text =
                      match['homeGoals']?.toString() ?? '';
                  _actualAwayScores[id]?.text =
                      match['awayGoals']?.toString() ?? '';
                }),
                child: const Text('Corregir'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _standingsCard(dynamic actual, List<Map<String, dynamic>> projected) {
    final rows = (actual as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_t('tournament.actual_standings', 'Tabla real'),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            for (var i = 0; i < rows.length; i++)
              Text(
                  '${i + 1}. ${rows[i]['teamName']}  •  ${rows[i]['points']} pts  •  DG ${rows[i]['goalDifference']}'),
            const Divider(),
            const Text('Tu proyección',
                style: TextStyle(fontWeight: FontWeight.w800)),
            for (var i = 0; i < projected.length; i++)
              Text(
                  '${i + 1}. ${projected[i]['name']}  •  ${projected[i]['points']} pts  •  DG ${(projected[i]['gf'] as int) - (projected[i]['ga'] as int)}'),
          ],
        ),
      ),
    );
  }

  Widget _predictionCard(
    List<Map<String, dynamic>> teams,
    List<Map<String, dynamic>> matches,
    List<Map<String, dynamic>> projected,
    bool open,
  ) {
    final mayEdit = open && (_view?['myPrediction'] != null || open);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              open ? 'Tus pronósticos · abiertos' : 'Pronósticos · cerrados',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(_t(
              'tournament.enter_group_scores',
              'Completa los seis marcadores del todos contra todos.',
            )),
            for (final match
                in matches.where((m) => m['phase'] == 'ROUND_ROBIN'))
              _predictionMatch(match),
            const Divider(),
            Text(
                'Final: ${projected.isNotEmpty ? projected[0]['name'] : '-'} vs ${projected.length > 1 ? projected[1]['name'] : '-'}'),
            _scoreInputs('final', enabled: mayEdit),
            Text(
                'Tercer puesto: ${projected.length > 2 ? projected[2]['name'] : '-'} vs ${projected.length > 3 ? projected[3]['name'] : '-'}'),
            _scoreInputs('third-place', enabled: mayEdit),
            if (open)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _busy ? null : () => _savePrediction(teams),
                  child: const Text('Guardar pronósticos'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _predictionMatch(Map<String, dynamic> match) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_teamName(match['homeTeamId'])} vs ${_teamName(match['awayTeamId'])}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _scoreField(_controller(_homeScores, match['id']),
                enabled: _isOpen),
            const Text(' - '),
            _scoreField(_controller(_awayScores, match['id']),
                enabled: _isOpen),
          ],
        ),
      );

  bool get _isOpen =>
      ((_tournament?['groupPredictionPeriod'] as Map?)?['status'] ?? '') ==
      'OPEN';

  Widget _scoreInputs(String id, {required bool enabled}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            const Spacer(),
            _scoreField(_controller(_homeScores, id), enabled: enabled),
            const Text(' - '),
            _scoreField(_controller(_awayScores, id), enabled: enabled),
          ],
        ),
      );

  Widget _scoreField(TextEditingController controller,
          {required bool enabled}) =>
      SizedBox(
        width: 54,
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            counterText: '',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          ),
          maxLength: 2,
          onChanged: (_) => setState(() {}),
        ),
      );

  Widget _leaderboardCard(dynamic value) {
    final rows = (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_t('tournament.leaderboard', 'Ranking'),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (rows.isEmpty)
              const Text(
                  'El ranking se está calculando. Desliza para actualizar.')
            else
              for (final row in rows)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(child: Text('${row['place']}')),
                  title: Text(row['displayName']?.toString() ?? 'Participante'),
                  trailing: Text('${row['points']} pts'),
                ),
          ],
        ),
      ),
    );
  }

  String _teamName(dynamic id) {
    if (id == null) return 'Por definir';
    for (final team in _teams) {
      if (team['id'] == id) return team['name']?.toString() ?? '-';
    }
    return '-';
  }
}
