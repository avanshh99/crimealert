# Crime Alert

Crime Alert is a Flutter-based mobile application designed to report and track crimes in real-time. The app allows users to submit crime reports, view crime alerts on a map, and manage their profiles. It integrates with Firebase for authentication, Firestore for data storage, and Google Maps for location-based features.

## Features

- **Crime Reporting**: Users can report crimes by providing details such as location, type of crime, description, and evidence (images or files).
- **Real-Time Alerts**: View crime alerts on a map with markers for reported incidents.
- **User Profiles**: Manage user profiles, including updating personal information and profile pictures.
- **SOS Messaging**: Send emergency SOS messages to predefined contacts or authorities.
- **Post Feed**: Share and view posts related to community safety and crime prevention.

## Installation

1. Clone the repository:
   ```sh
   git clone https://github.com/your-username/crime-alert.git
   cd crime-alert
   ```

2. Install dependencies:
   ```sh
   flutter pub get
   ```

3. Configure Firebase:
   - Add your `google-services.json` file to the `android/app` directory.
   - Add your `GoogleService-Info.plist` file to the `ios/Runner` directory.

4. Run the app:
   ```sh
   flutter run
   ```

## Project Structure

```
crime_alert/
├── android/                # Android-specific files
├── ios/                    # iOS-specific files
├── lib/                    # Main Flutter application code
│   ├── views/              # UI screens
│   ├── models/             # Data models
│   ├── services/           # Firebase and other service integrations
│   └── widgets/            # Reusable UI components
├── assets/                 # Static assets (images, icons, etc.)
├── test/                   # Unit and widget tests
├── pubspec.yaml            # Flutter dependencies
└── README.md               # Project documentation
```

## Dependencies

The project uses the following key dependencies:

- **Firebase**:
  - `firebase_core`
  - `firebase_auth`
  - `cloud_firestore`
  - `firebase_storage`
- **Google Maps**:
  - `google_maps_flutter`
- **Location Services**:
  - `geolocator`
  - `geocoding`
- **Media Handling**:
  - `image_picker`
  - `flutter_image_compress`
- **UI Enhancements**:
  - `fluttertoast`
  - `intl`

For a full list of dependencies, see the [pubspec.yaml](pubspec.yaml) file.


## APIs Used

The application integrates with the following APIs:

1. **Firebase APIs**:
   - Firebase Authentication for user login and registration.
   - Firestore for storing and retrieving crime reports and user data.
   - Firebase Storage for uploading and retrieving media files.

2. **Google Maps API**:
   - Used for displaying crime locations on a map and providing geolocation services.

3. **Geocoding API**:
   - Converts latitude and longitude into human-readable addresses.

4. **Custom SMS API**:
   - A custom API hosted at `http://192.168.156.1:5000/send-sms` for sending SOS messages to predefined contacts or authorities.

   **Example Request**:
   ```json
   POST http://192.168.156.1:5000/send-sms
   Content-Type: application/json

   {
     "to": "+1234567890",
     "message": "SOS! Immediate Help Required. Location: Lat: 12.9716, Long: 77.5946"
   }
   ```

   **Response**:
   ```json
   {
     "status": "success",
     "message": "SMS sent successfully"
   }
   ```

## Usage

1. **Report a Crime**:
   - Navigate to the "Crime Report" screen.
   - Fill in the details, attach evidence, and submit the report.

2. **View Crime Alerts**:
   - Open the home screen to view crime markers on the map.

3. **Manage Profile**:
   - Go to the "Account" screen to update your profile information.

4. **Send SOS**:
   - Use the "SOS" feature to send emergency messages.

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bug fix:
   ```sh
   git checkout -b feature-name
   ```
3. Commit your changes and push to your fork:
   ```sh
   git commit -m "Add feature-name"
   git push origin feature-name
   ```
4. Open a pull request.


## Acknowledgments

- [Flutter](https://flutter.dev/)
- [Firebase](https://firebase.google.com/)
- [Google Maps](https://developers.google.com/maps)

## Contact

For questions or support, please contact [avanshetty196@gmail.com].