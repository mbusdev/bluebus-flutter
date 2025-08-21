import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_screen.dart';

// Terms & Privacy text
const String TERMS_AND_CONDITIONS =
    "MaizeBus or UM Transit APIs are not responsible or liable for any viruses or other contamination of your system or for any delays, inaccuracies, errors or omissions arising out of your use of the application or with respect to the material contained on the application, including without limitation, any material posted on the application. This application and all materials contained on it are distributed and transmitted \"as is\" without warranties of any kind, either express or implied, including without limitation, warranties of title or implied warranties of merchantability or fitness for a particular purpose. MaizeBus or UM Transit are not liable for any actual, special, indirect, incidental or consequential damages that may arise from the use of, or the inability to use, the application and or the materials contained on the application whether the materials contained on the application are provided by the MaizeBus, UM Transit, or a third party.\n\nTerms of use adapted from UM Magic Bus Terms of Use at https://mbus.ltp.umich.edu/terms-use";
const String PRIVACY_POLICY =
    "This section details the user data MaizeBus collects and how the data are used and treated.\n\nMaizeBus as an entity does not store or collect any information about you. However, MaizeBus utilizes the University of Michigan Magic Bus API, which does collect some information about you. As the Magic Bus Terms of Service state, \"We automatically collect and store technical information about your visit to our site including: (1) the name of the domain and host from which you access the Internet; (2) the type of browser software and operating system used to access our site; (3) the date and time you access our site; and (4) the pages you visit on our site. The technical information collected will not personally identify you. We also store technical information that we collect through cookies and log files to create a profile of our customers. The profile information is used to improve the content of the site, to perform a statistical analysis of use of the site and to enhance use of the site. Technical information stored in a profile will not be linked to any personal information provided to us through your other use of our websites.\"\n\nPlease refer to the U-M Magic Bus Terms of Service at https://mbus.ltp.umich.edu/terms-use for the latest versions of the U-M Magic Bus documents.\n\nAdditionally, MaizeBus provides your location to Google Maps SDK to display your location on the map. Information about how Google Maps handles your data can be located at http://www.google.com/policies/privacy";

// OnboardingDecider checks if the user has already accepted terms.
// If not, it presents a fullscreen PageView with Welcome and Terms pages.
class OnboardingDecider extends StatefulWidget {
  const OnboardingDecider({super.key});

  @override
  State<OnboardingDecider> createState() => _OnboardingDeciderState();
}

class _OnboardingDeciderState extends State<OnboardingDecider> {
  bool _checking = true;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _checkAccepted();
  }

  Future<void> _checkAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('accepted_terms') ?? false;
    setState(() {
      _accepted = accepted;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()), resizeToAvoidBottomInset: false);
    }

    if (_accepted) {
      return const Scaffold(body: MapScreen(), resizeToAvoidBottomInset: false);
    }

    return const OnboardingScreen();
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool _agreeChecked = false;

  Future<void> _setAccepted(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accepted_terms', v);
    if (v) {
      // Navigate to app
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => Scaffold(body: const MapScreen(), resizeToAvoidBottomInset: false)));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Welcome page
            Container(
              color: theme.scaffoldBackgroundColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to MaizeBus',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36.0),
                    child: Text(
                      'MaizeBus helps you find buses and stops around campus.\n\nTap Continue to view Terms & Conditions.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),

            // Terms & Conditions + Privacy page
            Container(
              color: theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Terms & Conditions & Privacy',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(TERMS_AND_CONDITIONS),
                          const SizedBox(height: 16),
                          const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(PRIVACY_POLICY),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeChecked,
                        onChanged: (v) {
                          setState(() {
                            _agreeChecked = v ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I have read and agree to the Terms & Conditions and Privacy Policy',
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () async {
                          if (mounted) Navigator.of(context).maybePop();
                        },
                        child: const Text('Decline'),
                      ),
                      ElevatedButton(
                        onPressed: _agreeChecked
                            ? () => _setAccepted(true)
                            : null,
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
