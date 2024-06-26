import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kmrapp/screens/tca_appointment_review.dart';
import 'package:table_calendar/table_calendar.dart';

class TCAAppointmentPage extends StatefulWidget {
  final DocumentReference staffData;
  final DocumentReference userData;
  const TCAAppointmentPage(
      {Key? key, required this.staffData, required this.userData})
      : super(key: key);

  @override
  _TCAAppointmentPageState createState() => _TCAAppointmentPageState();
}

class _TCAAppointmentPageState extends State<TCAAppointmentPage> {
  final user = FirebaseAuth.instance.currentUser!;
  late List<QueryDocumentSnapshot<Map<String, dynamic>>> userInfo = [];
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedTimeSlot;

  // Dummy time slots for the sake of example.
  final List<String> _timeSlots = [
    '9:00 am - 10:00 am',
    '10:00 am - 11:00 am',
    '11:00 am - 12:00 pm',
    '1:00 pm - 2:00 pm',
    '2:00 pm - 3:00 pm',
    '3:00 pm - 3:45 pm',
    '3:00 pm - 4:00 pm',
    '4:00 pm - 5:00 pm',
  ];

  Future<DocumentSnapshot<Map<String, dynamic>>> getStaffInfo() async {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Appointments')
        .get()
        .then((value) async {
      for (var docSnapshot in value.docs) {
        userInfo.add(docSnapshot);
        print(docSnapshot);
      }
    });
    return await widget.staffData.get()
        as DocumentSnapshot<Map<String, dynamic>>;
  }

  void bookAppointment(Map<String, dynamic> data) async {
    String doc =
        _selectedDay!.day.toString() + " " + _selectedDay!.month.toString();
    widget.staffData.collection('Appointments').doc(doc).set({
      "timeSlots":
          FieldValue.arrayUnion([_timeSlots.indexOf(_selectedTimeSlot!)]),
    }, SetOptions(merge: true));
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Appointments')
        .doc(doc)
        .set({
      "timeSlots":
          FieldValue.arrayUnion([_timeSlots.indexOf(_selectedTimeSlot!)]),
      "staffInfo": FieldValue.arrayUnion([
        {
          "name": data["name"],
          "occupation": widget.staffData.parent.parent!.id,
        },
      ])
    }, SetOptions(merge: true));
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> isFreeList() async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> list = [];
    await widget.staffData.collection('Appointments').get().then((value) {
      for (var docSnapshot in value.docs) {
        list.add(docSnapshot);
      }
    });

    return list;
  }

  bool isFree(DateTime day, Map<String, dynamic> staffData,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> list) {
    String dbDoc = day.day.toString() + " " + day.month.toString();

    for (var docSnapshot in list) {
      if (dbDoc == docSnapshot.id) {
        final data = docSnapshot.data();
        if (data["timeSlots"].length == staffData["timeSlots"].length) {
          return false;
        }
      }
    }

    return true;
  }

  bool isTimeSlotFree(DateTime day, Map<String, dynamic> staffData,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> list, int i) {
    String dbDoc = day.day.toString() + " " + day.month.toString();

    for (var docSnapshot in list) {
      if (dbDoc == docSnapshot.id) {
        final data = docSnapshot.data();
        for (var index in data["timeSlots"]) {
          if (index == staffData["timeSlots"][i]) {
            return false;
          }
          for (var userData in userInfo) {
            for (var timeSlot in userData.data()["timeSlots"]) {
              if (timeSlot == staffData["timeSlots"][i]) {
                return false;
              }
            }
          }
        }
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 100,
          titleSpacing: 0,
          centerTitle: true,
          title: _buildAppBarTitle(),
        ),
        body: FutureBuilder(
            future: getStaffInfo(),
            builder: (context, snapshot) {
              if (!snapshot.hasData &&
                  snapshot.connectionState != ConnectionState.done) {
                return CircularProgressIndicator();
              } else {
                final data = snapshot.data!.data();
                _selectedDay = _focusedDay;
                return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(
                            "Schedule your appointment with",
                            style: TextStyle(fontSize: 20),
                          ),
                          Text(
                            data!["name"],
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                          SizedBox(
                            height: 30,
                          ),
                          _buildTableCalendar(data),
                          _buildTimeSlots(data),
                          SizedBox(height: 100),
                          _buildBookAppointmentButton(data),
                        ],
                      ),
                    ));
              }
            }));
  }

  Widget _buildAppBarTitle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      width: double.infinity,
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xffDFCEFA),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 24,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  size: 24.0,
                  color: Color.fromARGB(255, 150, 111, 214),
                ),
              ),
            ),
            const Text(
              'TCA / BSSK',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xff966FD6),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCalendar(Map<String, dynamic> data) {
    return Column(
      children: [
        FutureBuilder(
            future: isFreeList(),
            builder: (context, list) {
              if (!list.hasData &&
                  list.connectionState != ConnectionState.done) {
                return CircularProgressIndicator();
              } else {
                return TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  enabledDayPredicate: (day) {
                    bool isFreeBool = isFree(day, data, list.data!);
                    for (int dayDB in data["days"]) {
                      if (dayDB == day.weekday && isFreeBool) {
                        return true;
                      }
                    }

                    return false;
                  },
                  onPageChanged: (focusedDay) =>
                      setState(() => _focusedDay = focusedDay),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    leftChevronVisible: true,
                    rightChevronVisible: true,
                    headerMargin: EdgeInsets.only(
                        bottom:
                            20), // Creates a gap between the header title and the calendar grid
                    leftChevronPadding: EdgeInsets.only(
                        left: 16), // Adds padding to the left chevron
                    rightChevronPadding: EdgeInsets.only(
                        right: 16), // Adds padding to the right chevron
                    titleTextStyle:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }
            }),
      ],
    );
  }

  Widget _buildTimeSlots(Map<String, dynamic> data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the width of the buttons based on the screen width and desired padding
        double buttonWidth = (constraints.maxWidth - 10) /
            2; // Subtracting the spacing between the buttons

        return FutureBuilder(
            future: isFreeList(),
            builder: (context, snapshot) {
              if (!snapshot.hasData &&
                  snapshot.connectionState != ConnectionState.done) {
                return CircularProgressIndicator();
              } else {
                final list = snapshot.data!;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: buttonWidth /
                        48, // Adjust based on your button's height
                  ),
                  itemCount: data["timeSlots"].length,
                  itemBuilder: (context, index) {
                    if (isTimeSlotFree(_selectedDay!, data, list, index)) {
                      bool isSelected = _selectedTimeSlot ==
                          _timeSlots[data["timeSlots"][index]];
                      return ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTimeSlot =
                                _timeSlots[data["timeSlots"][index]];
                          });
                        },
                        child: Text(
                          _timeSlots[data["timeSlots"][index]],
                          style: TextStyle(
                            fontSize: 16, // This is your font size
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor:
                              isSelected ? Colors.white : Colors.black,
                          backgroundColor:
                              isSelected ? Colors.deepPurple : Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      );
                    }
                  },
                  padding: EdgeInsets.zero, // No additional padding
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                );
              }
            });
      },
    );
  }

  Widget _buildBookAppointmentButton(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      width:
          double.infinity, // Ensure the button takes the full width available
      child: ElevatedButton(
        onPressed: () {
          if (_selectedDay != null && _selectedTimeSlot != null) {
            bookAppointment(data);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => TCAAppointmentReview(
                      day: _selectedDay!,
                      timeSlot: _selectedTimeSlot!,
                      name: data["name"])),
            );
          }
        },
        child: const Text(
          'Book Appointment',
          style: TextStyle(fontSize: 17),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white, backgroundColor: Colors.deepPurple,
          padding: const EdgeInsets.symmetric(
            vertical: 35.0,
          ), // Add more vertical padding for height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                50.0), // Match the border radius as per design
          ),
        ),
      ),
    );
  }
}
