import 'package:bluebus/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:bluebus/globals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../util/favorite_building_storage.dart';


void sendEmailWithSender(BuildContext context, String emailSubject, String emailBody) async {
  final Email email = Email(
    body: emailBody,
    subject: emailSubject,
    recipients: ['ishaniik@umich.edu'],
    isHTML: false,
  );

  try {
    await FlutterEmailSender.send(email);
  } catch (error) {
    showFallbackOptions(context);
  }
}

void showFallbackOptions(BuildContext context) {
  showMaizebusOKDialog(
    contextIn: context,
    title: "Email-Send failed",
    content: "Unable to reach the email app on your device. You can still send us feedback by manually emailing contact@maizebus.com",
  );
}

// Selecting routes
class BuildingSheet extends StatefulWidget {
  final Location building;
  final void Function(Location) onGetDirections;

  const BuildingSheet({
    Key? key,
    required this.building,
    required this.onGetDirections,
  }) : super(key: key);

  @override
  State<BuildingSheet> createState() => _BuildingSheetState();
}

// State for the route selector
class _BuildingSheetState extends State<BuildingSheet> {
  bool _isFavoriteBuilding = false;

  String _favoriteStorageId() => favoriteBuildingStorageId(widget.building);

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(kFavoriteBuildingsPrefsKey) ?? <String>[];
    final id = _favoriteStorageId();
    if (!mounted) return;
    setState(() {
      _isFavoriteBuilding =
          list.any((s) => favoriteBuildingEntryId(s) == id);
    });
  }

  Future<void> _toggleFavoriteBuilding() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _favoriteStorageId();
    final list =
        List<String>.from(prefs.getStringList(kFavoriteBuildingsPrefsKey) ?? <String>[]);
    if (_isFavoriteBuilding) {
      list.removeWhere((s) => favoriteBuildingEntryId(s) == id);
    } else {
      list.removeWhere((s) => favoriteBuildingEntryId(s) == id);
      list.add(encodeFavoriteBuilding(widget.building));
    }
    await prefs.setStringList(kFavoriteBuildingsPrefsKey, list);
    if (!mounted) return;
    setState(() {
      _isFavoriteBuilding = !_isFavoriteBuilding;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getColor(context, ColorType.background),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.building.name,
              softWrap: true,
              style: TextStyle(
                fontFamily: 'Urbanist',
                fontWeight: FontWeight.w700,
                fontSize: 36,
                height: 1.2,
                color: getColor(context, ColorType.opposite),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // show different subtitle depending on whether one exists
          (widget.building.abbrev != "")
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Building code: ',
                        style: TextStyle(
                          fontFamily: 'Urbanist',
                          fontWeight: FontWeight.w400,
                          fontSize: 20,
                          color: getColor(context, ColorType.opposite),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          widget.building.abbrev,
                          style: const TextStyle(
                            color: Colors.black,
                            fontFamily: 'Urbanist',
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'No building code',
                    style: TextStyle(
                      fontFamily: 'Urbanist',
                      fontWeight: FontWeight.w400,
                      fontSize: 20,
                      color: getColor(context, ColorType.opposite),
                    ),
                  ),
                ),

          const SizedBox(height: 24),
      
          // One row: wide pills share space evenly; tight padding + FittedBox labels avoid "Directi…".
          Padding(
            padding: EdgeInsets.only(
              left: globalLeftRightPadding,
              right: globalLeftRightPadding,
              bottom: globalBottomPadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onGetDirections(widget.building);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          getColor(context, ColorType.importantButtonBackground),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                      minimumSize: Size.zero,
                    ),
                    icon: Icon(
                      Icons.directions,
                      color: getColor(context, ColorType.importantButtonText),
                      size: 18,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Directions',
                        maxLines: 1,
                        style: TextStyle(
                          color: getColor(context, ColorType.importantButtonText),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(contactURL),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          getColor(context, ColorType.secondaryButtonBackground),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                      minimumSize: Size.zero,
                    ),
                    icon: Icon(
                      Icons.report,
                      color: getColor(context, ColorType.secondaryButtonText),
                      size: 18,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Feedback',
                        maxLines: 1,
                        style: TextStyle(
                          color: getColor(context, ColorType.secondaryButtonText),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  elevation: 3,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  color: getColor(context, ColorType.secondaryButtonBackground),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleFavoriteBuilding,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        _isFavoriteBuilding
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _isFavoriteBuilding
                            ? Colors.red
                            : getColor(context, ColorType.secondaryButtonText),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
} 