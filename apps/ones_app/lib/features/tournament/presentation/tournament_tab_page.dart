import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/i18n/translations_service.dart';
import '../adapters/api/tournament_api_repository.dart';
import 'leaderboard_rows.dart';
import 'prediction_feedback.dart';
import 'prediction_result_summary.dart';
import 'prediction_score_field.dart';

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
  List<Map<String, dynamic>> _participants = const [];
  final Set<String> _delegates = {};
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _initializedFields = false;
  bool _membersLoadError = false;
  bool _participantsLoaded = false;

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
          _controller(_actualHomeScores, id).text = match['homeGoals']
              .toString();
        }
        if (match['awayGoals'] != null) {
          _controller(_actualAwayScores, id).text = match['awayGoals']
              .toString();
        }
      }
      final shouldLoadParticipants =
          value['owner'] == true || value['forecastsRevealed'] == true;
      var participantsLoaded = false;
      var participantsLoadError = false;
      List<Map<String, dynamic>> participants = const [];
      if (shouldLoadParticipants) {
        try {
          participants = await _api!.eventMembers(widget.eventId);
          participantsLoaded = true;
        } on DioException {
          participantsLoadError = true;
          participants = const [];
        }
      }
      if (value['owner'] == true) {
        _members = participants
            .where((member) => member['status'] == 'accepted')
            .toList(growable: false);
        _delegates
          ..clear()
          ..addAll(
            List<String>.from(tournament['delegateUserIds'] ?? const []),
          );
      }
      if (!mounted) return;
      setState(() {
        _view = value;
        _participants = participants;
        _participantsLoaded = participantsLoaded;
        _membersLoadError = participantsLoadError;
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

  Future<void> _savePrediction() async {
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

  Future<void> _recalculateScores() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recalcular puntajes'),
        content: const Text(
          'Se volverán a calcular los puntos de todos los invitados usando '
          'los resultados oficiales. El ranking puede tardar unos momentos en actualizarse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Recalcular'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final queued = await _api!.recalculateScores(widget.eventId);
      _toast(
        queued
            ? 'Recálculo solicitado. Actualiza el ranking en unos momentos.'
            : 'Ya hay un recálculo reciente en proceso. Espera antes de solicitar otro.',
      );
    } catch (e) {
      _toast('No se pudo solicitar el recálculo: ${_actionError(e)}');
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
            if (_view?['forecastsRevealed'] == true &&
                _matches.any((match) => match['status'] == 'FINISHED'))
              OutlinedButton.icon(
                onPressed: _busy ? null : _recalculateScores,
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Recalcular puntos'),
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

  Widget _matchesCard(List<Map<String, dynamic>> matches, bool manager) {
    final theme = Theme.of(context);
    final finished = matches
        .where((match) => match['status'] == 'FINISHED')
        .length;
    final progress = matches.isEmpty ? 0.0 : finished / matches.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.sports_soccer_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          'tournament.actual_matches',
                          'Partidos y resultados reales',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        manager
                            ? 'Registra los marcadores oficiales del torneo.'
                            : 'El owner o delegado registra los resultados oficiales.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Avance del torneo')),
                      Text(
                        '$finished de ${matches.length}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (matches.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 30,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Los partidos aparecerán aquí cuando se configuren los cuatro equipos.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            )
            else
              for (var i = 0; i < matches.length; i++)
                _matchRow(matches[i], manager),
          ],
        ),
      ),
    );
  }

  Widget _matchRow(Map<String, dynamic> match, bool manager) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final id = match['id'] as String;
    final home = _teamName(match['homeTeamId']);
    final away = _teamName(match['awayTeamId']);
    final status = match['status']?.toString() ?? 'PENDING';
    final editing = _editingResults.contains(id);
    final canEditResult = manager && (status == 'IN_PROGRESS' || editing);
    final canStart = manager && status == 'PENDING' && home != 'Por definir';
    final isFinished = status == 'FINISHED' && !editing;
    final scoreTied =
        _actualHomeScores[id]?.text == _actualAwayScores[id]?.text &&
        _actualHomeScores[id]?.text.isNotEmpty == true;
    final needsPenaltyWinner =
        manager &&
        status == 'IN_PROGRESS' &&
        match['phase'] != 'ROUND_ROBIN' &&
        scoreTied;
    final statusColor = switch (status) {
      'FINISHED' => colors.primary,
      'IN_PROGRESS' => colors.tertiary,
      _ => colors.outline,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _matchPhaseLabel(match),
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                _matchStatusBadge(status, statusColor),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    home,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (canEditResult) ...[
                  _actualScoreField(id, homeSide: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      '–',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _actualScoreField(id, homeSide: false),
                ] else if (isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${match['homeGoals']} – ${match['awayGoals']}',
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: colors.outline,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    away,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (needsPenaltyWinner) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: colors.onTertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El partido está empatado. Selecciona quién gana por penales.',
                            style: TextStyle(
                              color: colors.onTertiaryContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButton<String>(
                      value: _penaltyWinners[id],
                      isExpanded: true,
                      hint: const Text('Elegir ganador por penales'),
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
                  ],
                ),
              ),
            ],
            if (canStart ||
                (manager && (status == 'IN_PROGRESS' || editing)) ||
                (manager && status == 'FINISHED' && !editing)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (canStart)
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => _startMatch(id),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Iniciar partido'),
                    ),
                  if (manager && (status == 'IN_PROGRESS' || editing))
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _finishMatch(match),
                      icon: Icon(
                        editing
                            ? Icons.save_outlined
                            : Icons.sports_score_outlined,
                      ),
                      label: Text(
                        editing ? 'Guardar corrección' : 'Finalizar partido',
                      ),
                    ),
                  if (manager && status == 'FINISHED' && !editing)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _editingResults.add(id);
                        _actualHomeScores[id]?.text =
                            match['homeGoals']?.toString() ?? '';
                        _actualAwayScores[id]?.text =
                            match['awayGoals']?.toString() ?? '';
                      }),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Corregir resultado'),
                    ),
                  if (manager && editing)
                    TextButton(
                      onPressed: () => setState(() {
                        _editingResults.remove(id);
                        _actualHomeScores[id]?.text =
                            match['homeGoals']?.toString() ?? '';
                        _actualAwayScores[id]?.text =
                            match['awayGoals']?.toString() ?? '';
                      }),
                      child: const Text('Cancelar'),
                    ),
                ],
              ),
            ],
            if (status == 'PENDING' && home == 'Por definir') ...[
              const SizedBox(height: 10),
              Text(
                'Los equipos se asignarán al cerrar la fase de todos contra todos.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _matchPhaseLabel(Map<String, dynamic> match) =>
      switch (match['phase']) {
        'FINAL' => 'Final',
        'THIRD_PLACE' => 'Tercer puesto',
        _ => 'Todos contra todos',
      };

  Widget _matchStatusBadge(String status, Color color) {
    final (label, icon) = switch (status) {
      'FINISHED' => ('Finalizado', Icons.check_circle_outline),
      'IN_PROGRESS' => ('En juego', Icons.play_circle_outline),
      _ => ('Pendiente', Icons.schedule_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actualScoreField(String matchId, {required bool homeSide}) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            homeSide ? 'LOCAL' : 'VISITA',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _controller(
                homeSide ? _actualHomeScores : _actualAwayScores,
                matchId,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              maxLength: 2,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide(color: colors.primary, width: 1.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _standingsCard(dynamic actual, List<Map<String, dynamic>> projected) {
    final actualRows = (actual as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map<Map<String, dynamic>>((item) => {
              'teamName': item['teamName'] ?? '-',
              'played': item['played'] ?? 0,
              'wins': item['wins'] ?? 0,
              'draws': item['draws'] ?? 0,
              'losses': item['losses'] ?? 0,
              'goalsFor': item['goalsFor'] ?? 0,
              'goalsAgainst': item['goalsAgainst'] ?? 0,
              'goalDifference': item['goalDifference'] ?? 0,
              'points': item['points'] ?? 0,
            })
        .toList();
    final projectedRows = projected
        .map<Map<String, dynamic>>((item) => {
              'teamName': item['name'] ?? '-',
              'played': item['played'] ?? 0,
              'wins': item['wins'] ?? 0,
              'draws': item['draws'] ?? 0,
              'losses': item['losses'] ?? 0,
              'goalsFor': item['gf'] ?? 0,
              'goalsAgainst': item['ga'] ?? 0,
              'goalDifference':
                  (item['gf'] as int? ?? 0) - (item['ga'] as int? ?? 0),
              'points': item['points'] ?? 0,
            })
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _standingsTable(
              _t('tournament.actual_standings', 'Tabla real'),
              actualRows,
            ),
            const Divider(),
            _standingsTable('Tu proyección', projectedRows),
          ],
        ),
      ),
    );
  }

  Widget _standingsTable(String title, List<Map<String, dynamic>> rows) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 32),
                  child: Text('Equipo'),
                ),
              ),
              _standingsMetric('PJ', 30, header: true),
              _standingsMetric('G-E-P', 54, header: true),
              _standingsMetric('GF-GC', 48, header: true),
              _standingsMetric('DG', 34, header: true),
              _standingsMetric('Pts', 38, header: true),
            ],
          ),
        ),
        for (var i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rows[i]['teamName']?.toString() ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                _standingsMetric('${rows[i]['played']}', 30),
                _standingsMetric(
                    '${rows[i]['wins']}-${rows[i]['draws']}-${rows[i]['losses']}',
                    54),
                _standingsMetric(
                    '${rows[i]['goalsFor']}-${rows[i]['goalsAgainst']}', 48),
                _standingsMetric('${rows[i]['goalDifference']}', 34),
                _standingsMetric('${rows[i]['points']}', 38, highlight: true),
              ],
            ),
          ),
          if (i < rows.length - 1) const Divider(height: 1),
        ],
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Aún no hay resultados para mostrar.'),
          ),
      ],
    );
  }

  Widget _standingsMetric(
    String value,
    double width, {
    bool header = false,
    bool highlight = false,
  }) =>
      SizedBox(
        width: width,
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: header ? 10 : 11,
            fontWeight:
                header || highlight ? FontWeight.w800 : FontWeight.w500,
            color: header
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
      );

  Widget _predictionCard(
    List<Map<String, dynamic>> matches,
    List<Map<String, dynamic>> projected,
    bool open,
  ) {
    final groupMatches = matches
        .where((match) => match['phase'] == 'ROUND_ROBIN')
        .toList();
    final registered = groupMatches
        .where((match) => _scoreFor(match['id'].toString()) != null)
        .length;
    final finalMatch = _matchForPhase(matches, 'FINAL');
    final thirdPlaceMatch = _matchForPhase(matches, 'THIRD_PLACE');
    final finalHomeId = projected.isNotEmpty
        ? projected[0]['id']?.toString()
        : null;
    final finalAwayId = projected.length > 1
        ? projected[1]['id']?.toString()
        : null;
    final thirdHomeId = projected.length > 2
        ? projected[2]['id']?.toString()
        : null;
    final thirdAwayId = projected.length > 3
        ? projected[3]['id']?.toString()
        : null;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('tournament.my_predictions', 'Tus pronósticos'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        open
                            ? 'Completa ambos marcadores; los vacíos no son cero. Los colores son una vista previa.'
                            : 'Pronósticos cerrados. Los colores reflejan el resultado oficial.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _predictionPeriodBadge(open),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 19,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Partidos de grupos registrados'),
                      ),
                      Text(
                        '$registered de ${groupMatches.length}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: groupMatches.isEmpty
                        ? 0
                        : registered / groupMatches.length,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _predictionLegend(),
            const SizedBox(height: 12),
            for (final match in groupMatches)
              _predictionFixtureRow(
                id: match['id'].toString(),
                phaseLabel: 'Todos contra todos',
                homeTeamName: _teamName(match['homeTeamId']),
                awayTeamName: _teamName(match['awayTeamId']),
                actualMatch: match,
                enabled: open,
              ),
            const Divider(height: 24),
            Text(
              'Fase final',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            _predictionFixtureRow(
              id: 'final',
              phaseLabel: 'Final',
              homeTeamName: finalHomeId == null
                  ? 'Por definir'
                  : projected[0]['name']?.toString() ?? 'Por definir',
              awayTeamName: finalAwayId == null
                  ? 'Por definir'
                  : projected[1]['name']?.toString() ?? 'Por definir',
              actualMatch: finalMatch,
              expectedHomeTeamId: finalHomeId,
              expectedAwayTeamId: finalAwayId,
              compareFixture: true,
              enabled: open,
            ),
            _predictionFixtureRow(
              id: 'third-place',
              phaseLabel: 'Tercer puesto',
              homeTeamName: thirdHomeId == null
                  ? 'Por definir'
                  : projected[2]['name']?.toString() ?? 'Por definir',
              awayTeamName: thirdAwayId == null
                  ? 'Por definir'
                  : projected[3]['name']?.toString() ?? 'Por definir',
              actualMatch: thirdPlaceMatch,
              expectedHomeTeamId: thirdHomeId,
              expectedAwayTeamId: thirdAwayId,
              compareFixture: true,
              enabled: open,
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _savePrediction,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar pronósticos'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _predictionPeriodBadge(bool open) {
    final colors = Theme.of(context).colorScheme;
    final color = open ? colors.primary : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            open ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            open ? 'Abiertos' : 'Cerrados',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _predictionLegend() {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _predictionLegendItem(Colors.green.shade700, 'Ese marcador coincide'),
        _predictionLegendItem(Colors.orange.shade800, 'Acierto parcial'),
        _predictionLegendItem(colors.error, 'Ese marcador no coincide'),
        _predictionLegendItem(
          colors.onSurfaceVariant,
          'Ganador/empate sin puntos',
        ),
        _predictionLegendItem(colors.outline, 'Pendiente / sin evaluar'),
      ],
    );
  }

  Widget _predictionLegendItem(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );

  Widget _predictionFixtureRow({
    required String id,
    required String phaseLabel,
    required String homeTeamName,
    required String awayTeamName,
    required Map<String, dynamic>? actualMatch,
    required bool enabled,
    String? expectedHomeTeamId,
    String? expectedAwayTeamId,
    bool compareFixture = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final homeController = _controller(_homeScores, id);
    final awayController = _controller(_awayScores, id);
    final fixtureMatches =
        !compareFixture ||
        (expectedHomeTeamId != null &&
            expectedAwayTeamId != null &&
            expectedHomeTeamId == actualMatch?['homeTeamId']?.toString() &&
            expectedAwayTeamId == actualMatch?['awayTeamId']?.toString());
    final feedback = PredictionFeedback.evaluate(
      predictedHome: int.tryParse(homeController.text),
      predictedAway: int.tryParse(awayController.text),
      actualHome: int.tryParse(actualMatch?['homeGoals']?.toString() ?? ''),
      actualAway: int.tryParse(actualMatch?['awayGoals']?.toString() ?? ''),
      matchFinished: actualMatch?['status'] == 'FINISHED',
      fixtureMatches: fixtureMatches,
    );
    final badgeColor = _feedbackColor(feedback.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  phaseLabel,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _predictionFeedbackBadge(
                feedback,
                color: badgeColor,
                enabled: enabled,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'TU PRONÓSTICO',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  homeTeamName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Marcador de $homeTeamName',
                child: _scoreField(
                  homeController,
                  enabled: enabled,
                  scoreCorrect: feedback.homeScoreCorrect,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '–',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Tooltip(
                message: 'Marcador de $awayTeamName',
                child: _scoreField(
                  awayController,
                  enabled: enabled,
                  scoreCorrect: feedback.awayScoreCorrect,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  awayTeamName,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PredictionResultSummary(
            actualHomeName: _teamName(actualMatch?['homeTeamId']),
            actualAwayName: _teamName(actualMatch?['awayTeamId']),
            actualHomeGoals:
                int.tryParse(actualMatch?['homeGoals']?.toString() ?? ''),
            actualAwayGoals:
                int.tryParse(actualMatch?['awayGoals']?.toString() ?? ''),
            matchExists: actualMatch != null,
            finished: actualMatch?['status'] == 'FINISHED',
            feedback: feedback,
            predictedHomeName: homeTeamName,
            predictedAwayName: awayTeamName,
            compareFixture: compareFixture,
          ),
        ],
      ),
    );
  }

  Color _feedbackColor(PredictionFeedbackType type) {
    final colors = Theme.of(context).colorScheme;
    return switch (type) {
      PredictionFeedbackType.exact => Colors.green.shade700,
      PredictionFeedbackType.partialScore => Colors.orange.shade800,
      PredictionFeedbackType.correctOutcome => colors.onSurfaceVariant,
      PredictionFeedbackType.missed => colors.error,
      PredictionFeedbackType.fixtureMismatch => colors.onSurfaceVariant,
      _ => colors.onSurfaceVariant,
    };
  }

  String _predictionFeedbackLabel(
    PredictionFeedbackType type, {
    required bool enabled,
  }) => switch (type) {
    PredictionFeedbackType.waiting => 'Esperando resultado oficial',
    PredictionFeedbackType.missing => 'Sin pronóstico',
    PredictionFeedbackType.incomplete =>
      enabled ? 'Completa ambos marcadores' : 'Pronóstico incompleto',
    PredictionFeedbackType.exact => 'Marcador exacto',
    PredictionFeedbackType.partialScore => 'Acierto parcial',
    PredictionFeedbackType.correctOutcome => 'Ganador/empate · 0 pts',
    PredictionFeedbackType.missed => 'Ningún marcador acertado',
    PredictionFeedbackType.fixtureMismatch => 'Cruce distinto',
  };

  IconData _predictionFeedbackIcon(PredictionFeedbackType type) =>
      switch (type) {
        PredictionFeedbackType.waiting => Icons.schedule_rounded,
        PredictionFeedbackType.missing => Icons.edit_note_rounded,
        PredictionFeedbackType.incomplete => Icons.more_horiz_rounded,
        PredictionFeedbackType.exact => Icons.check_circle_rounded,
        PredictionFeedbackType.partialScore => Icons.adjust_rounded,
        PredictionFeedbackType.correctOutcome => Icons.info_outline_rounded,
        PredictionFeedbackType.missed => Icons.cancel_rounded,
        PredictionFeedbackType.fixtureMismatch => Icons.swap_horiz_rounded,
      };

  Widget _predictionFeedbackBadge(
    PredictionFeedback feedback, {
    required Color color,
    required bool enabled,
  }) {
    final type = feedback.type;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_predictionFeedbackIcon(type), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _predictionFeedbackLabel(type, enabled: enabled),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _matchForPhase(
    List<Map<String, dynamic>> matches,
    String phase,
  ) {
    for (final match in matches) {
      if (match['phase'] == phase) return match;
    }
    return null;
  }

  Widget _scoreField(
    TextEditingController controller, {
    required bool enabled,
    required bool? scoreCorrect,
  }) => PredictionScoreField(
    controller: controller,
    enabled: enabled,
    scoreCorrect: scoreCorrect,
    onChanged: (_) => setState(() {}),
  );

  Widget _leaderboardCard(dynamic value) {
    final entries = (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final currentPrediction = _view?['myPrediction'] is Map
        ? Map<String, dynamic>.from(_view!['myPrediction'] as Map)
        : null;
    final currentUserId = currentPrediction?['userId']?.toString();
    final rows = buildTournamentRankingRows(
      leaderboard: entries,
      participants: _participants,
      participantsLoaded: _participantsLoaded,
      myPrediction: currentPrediction,
    );
    final nameCounts = <String, int>{};
    for (final row in rows) {
      final key = row.displayName.trim().toLowerCase();
      nameCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('tournament.leaderboard', 'Ranking del torneo'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Puntajes procesados de las personas del evento.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Aún no hay participantes disponibles para mostrar.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 380;
                  return Table(
                    columnWidths: {
                      0: FixedColumnWidth(compact ? 36 : 44),
                      1: const FlexColumnWidth(3.8),
                      2: const FlexColumnWidth(2),
                      3: FixedColumnWidth(compact ? 58 : 68),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.65),
                      ),
                    ),
                    children: [
                      TableRow(
                        children: [
                          _rankingHeaderCell('Pos.'),
                          _rankingHeaderCell('Participante'),
                          _rankingHeaderCell('Aciertos'),
                          _rankingHeaderCell('Puntos', align: TextAlign.end),
                        ],
                      ),
                      for (final row in rows)
                        _rankingDataRow(
                          row,
                          currentUserId: currentUserId,
                          duplicateName:
                              nameCounts[row.displayName
                                  .trim()
                                  .toLowerCase()]! >
                              1,
                          colors: colors,
                        ),
                    ],
                  );
                },
              ),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Quien aún no registra pronósticos aparece sin puesto. '
                'Tu fila está marcada como TÚ.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rankingHeaderCell(String label, {TextAlign align = TextAlign.start}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      child: Text(
        label,
        textAlign: align,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  TableRow _rankingDataRow(
    TournamentRankingRow row, {
    required String? currentUserId,
    required bool duplicateName,
    required ColorScheme colors,
  }) {
    final isMine = row.userId == currentUserId;
    final isFirst = row.place == 1;
    final textColor = isFirst ? colors.onPrimaryContainer : colors.onSurface;
    final secondaryColor = isFirst
        ? colors.onPrimaryContainer.withValues(alpha: 0.82)
        : colors.onSurfaceVariant;
    final background = isFirst
        ? colors.primaryContainer
        : isMine
        ? colors.primaryContainer.withValues(alpha: 0.28)
        : colors.surface;

    Widget cell(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 11),
      child: child,
    );

    return TableRow(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      children: [
        cell(
          Text(
            row.place?.toString() ?? '—',
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
          ),
        ),
        cell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (isMine) _youBadge(onDark: isFirst),
                ],
              ),
              if (!row.hasPrediction)
                Text(
                  'Sin pronósticos',
                  style: TextStyle(color: secondaryColor, fontSize: 10),
                )
              else if (duplicateName && row.email != null)
                Text(
                  row.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: secondaryColor, fontSize: 10),
                ),
            ],
          ),
        ),
        cell(
          Text(
            row.hasPrediction
                ? '${row.exactCount} exactos\n${row.fivePointCount} parciales'
                : '—',
            style: TextStyle(
              color: secondaryColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
        cell(
          Text(
            '${row.points} pts',
            textAlign: TextAlign.end,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _youBadge({required bool onDark}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: onDark ? colors.onPrimaryContainer : colors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'TÚ',
        style: TextStyle(
          color: onDark ? colors.primaryContainer : colors.onPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w900,
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
