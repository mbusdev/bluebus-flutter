import 'package:flutter/material.dart';
import '../models/journey.dart';
import '../constants.dart';

class JourneyResultsWidget extends StatefulWidget {
  final List<Journey> journeys;

  const JourneyResultsWidget({super.key, required this.journeys});

  @override
  State<JourneyResultsWidget> createState() => _JourneyResultsWidgetState();
}

class _JourneyResultsWidgetState extends State<JourneyResultsWidget> {
  int? expandedIndex;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.journeys.length,
      itemBuilder: (context, index) {
        final journey = widget.journeys[index];
        final totalDuration = journey.arrivalTime - journey.departureTime;
        final numTransfers = journey.legs.length - 1;
        final isExpanded = expandedIndex == index;
        return GestureDetector(
          onTap: () {
            setState(() {
              expandedIndex = isExpanded ? null : index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isExpanded
                  ? SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 1.2,
                          child: _buildJourneyContent(context, journey, index, totalDuration, numTransfers),
                        ),
                      ),
                    )
                  : _buildJourneyContent(context, journey, index, totalDuration, numTransfers),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJourneyContent(BuildContext context, Journey journey, int index, int totalDuration, int numTransfers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Row
        Row(
          children: [
            Icon(Icons.directions_bus, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Journey ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text('${(totalDuration / 60).round()} min'),
            const SizedBox(width: 12),
            if (numTransfers > 0) ...[
              Icon(Icons.swap_horiz, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('$numTransfers transfer${numTransfers > 1 ? 's' : ''}'),
            ]
          ],
        ),
        const SizedBox(height: 10),
        // Timeline for each leg
        ...journey.legs.map((leg) => _buildLeg(context, leg)).toList(),
      ],
    );
  }

  Widget _buildLeg(BuildContext context, Leg leg) {
    final isBus = leg.rt != null && leg.rt!.isNotEmpty;
    final icon = isBus ? Icons.directions_bus : Icons.directions_walk;
    final color = isBus ? Colors.blue : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // <-- Align items to the top
          children: [
            // Icon and route chip in a row for proper alignment
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                if (isBus && leg.rt != null && leg.rt!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Chip(
                    label: Text(getPrettyRouteName(leg.rt!)),
                    backgroundColor: Colors.blue[50],
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            // Text below icon/route
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isBus ? 'Bus' : 'Walk', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                  const SizedBox(height: 4),
                  expandedIndex == null
                    ? Row(
                        children: [
                          Flexible(child: Text('${leg.origin} ', style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          if (leg.origin != leg.destination) ...[
                            const Icon(Icons.arrow_forward, size: 16),
                            Flexible(child: Text(' ${leg.destination}', style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leg.origin,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            softWrap: true,
                          ),
                          if (leg.origin != leg.destination) ...[
                            Row(
                              children: [
                                const Icon(Icons.arrow_forward, size: 16),
                                Expanded(
                                  child: Text(
                                    leg.destination,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 2),
            Text('${(leg.duration / 60).round()} min'),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}