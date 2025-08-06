// Backend url for the api
//const String BACKEND_URL = 'https://www.efeakinci.host/mbus/api/v3';
const String BACKEND_URL = 'https://mbus-310c2b44573c.herokuapp.com/mbus/api/v3/';

// Mapping from route code to full name
const Map<String, String> ROUTE_CODE_TO_NAME = {
  'CN': 'Commuter North',
  'CSX': 'Crisler Express',
  'MX': 'Med Express',
  'WS': 'Wall Street-NIB',
  'WX': 'Wall Street Express',
  'CS': 'Commuter South',
  'NW': 'Northwood',
  'NES': 'North-East Shuttle',
};

String getPrettyRouteName(String code) {
  final name = ROUTE_CODE_TO_NAME[code];
  return name != null ? '$code - $name' : code;
} 