import 'package:bluebus/models/floorplan.dart';
import 'package:bluebus/widgets/search_rooms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FloorplanPoi _poi(String id, String? name, {String type = 'room'}) =>
    FloorplanPoi(
      id: id,
      position: Offset.zero,
      type: type,
      name: name,
      roomId: null,
      navNodeId: null,
    );

FloorplanFloor _floor(String id, String name, List<FloorplanPoi> pois) =>
    FloorplanFloor(
      id: id,
      name: name,
      pxPerMeter: 1,
      width: 100,
      height: 100,
      walls: const [],
      rooms: const [],
      pois: pois,
      outline: const [],
      nav: FloorplanNavGraph.fromJson(null),
    );

final _fakeFloors = [
  _floor('f1', 'Floor 1', [
    _poi('p1', '1005 Duderstadt Atrium'),
    _poi('p2', '1180 Lab'),
    _poi('wp1', 'waypoint', type: FloorplanTypes.waypoint1),
    _poi('wp2', 'waypoint', type: FloorplanTypes.waypoint2),
  ]),
  _floor('f2', 'Floor 2', [
    _poi('p3', '2255 Lecture Hall'),
    _poi('p4', null), // unnamed POIs must not crash the search
    _poi('p5', '2001 LAB'),
  ]),
];

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;
  late List<({FloorplanFloor floor, FloorplanPoi poi})> selected;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
    selected = [];
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pumpSearchBar(
    WidgetTester tester, {
    List<FloorplanFloor>? floors,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoomSearchBar(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(),
              floors: floors ?? _fakeFloors,
              onLocationSelected: (floor, poi) =>
                  selected.add((floor: floor, poi: poi)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(); // rebuild with the new query
    await tester.pump(); // let the search future resolve
  }

  testWidgets('shows a room when its number is searched', (tester) async {
    await pumpSearchBar(tester);
    await search(tester, '1180');

    expect(find.widgetWithText(ListTile, '1180 Lab'), findsOneWidget);
    expect(find.text('Duderstadt Building Floor 1'), findsOneWidget);
    expect(find.text('2255 Lecture Hall'), findsNothing);
  });

  testWidgets('search is case-insensitive and trims whitespace', (
    tester,
  ) async {
    await pumpSearchBar(tester);
    await search(tester, '  lecture hall ');

    expect(find.text('2255 Lecture Hall'), findsOneWidget);
  });

  testWidgets('matches rooms across multiple floors', (tester) async {
    await pumpSearchBar(tester);
    await search(tester, 'lab');

    expect(find.text('1180 Lab'), findsOneWidget);
    expect(find.text('2001 LAB'), findsOneWidget);
    expect(find.text('Duderstadt Building Floor 1'), findsOneWidget);
    expect(find.text('Duderstadt Building Floor 2'), findsOneWidget);
  });

  testWidgets('no results for a room that does not exist', (tester) async {
    await pumpSearchBar(tester);
    await search(tester, '9999');

    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('waypoints never show up as results', (tester) async {
    await pumpSearchBar(tester);
    await search(tester, 'waypoint');

    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('unnamed POIs do not crash the search', (tester) async {
    await pumpSearchBar(tester);
    await search(tester, 'a');

    expect(tester.takeException(), isNull);
    expect(find.text('1005 Duderstadt Atrium'), findsOneWidget);
  });

  testWidgets('empty query shows no results', (tester) async {
    await pumpSearchBar(tester);
    await search(tester, '   ');

    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('tapping a result reports its floor and poi', (tester) async {
    await pumpSearchBar(tester);
    await search(tester, '2255');
    await tester.tap(find.text('2255 Lecture Hall'));
    await tester.pump();

    expect(selected, hasLength(1));
    expect(selected.single.floor.id, 'f2');
    expect(selected.single.poi.id, 'p3');
    expect(controller.text, '2255 Lecture Hall');
  });

  testWidgets('submitting selects the first match', (tester) async {
    await pumpSearchBar(tester);
    await tester.enterText(find.byType(TextField), 'lab');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();

    expect(selected, hasLength(1));
    expect(selected.single.poi.id, 'p2');
  });

  testWidgets('works with no floors loaded', (tester) async {
    await pumpSearchBar(tester, floors: const []);
    await search(tester, '1180');

    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
