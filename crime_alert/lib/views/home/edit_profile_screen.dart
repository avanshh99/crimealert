import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:crime_alert/models/user_model.dart';
import 'package:crime_alert/services/cloudinary_service.dart';
import 'package:crime_alert/services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;

  const EditProfileScreen({required this.userId, Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late UserModel _user;
  bool _isLoading = true;
  bool _hasChanges = false;
  dynamic _pickedImage; // File (mobile) or Uint8List (web)
  bool _hasNewImage = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _zipcodeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await FirestoreService.getUserData(widget.userId);
      if (userData != null) {
        setState(() {
          _user = userData;
          _initializeControllers();
          _isLoading = false;
        });
      } else {
        throw Exception('User data not found');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: ${e.toString()}')),
      );
    }
  }

  void _initializeControllers() {
    _firstNameController.text = _user.firstName;
    _lastNameController.text = _user.lastName;
    _emailController.text = _user.email;
    _mobileController.text = _user.mobileNo ?? '';
    _addressController.text = _user.address ?? '';
    _zipcodeController.text = _user.zipcode ?? '';
    _countryController.text = _user.country ?? '';
    _stateController.text = _user.state ?? '';
    _cityController.text = _user.city ?? '';
    _addListeners();
  }

  void _addListeners() {
    _firstNameController.addListener(_checkForChanges);
    _lastNameController.addListener(_checkForChanges);
    _emailController.addListener(_checkForChanges);
    _mobileController.addListener(_checkForChanges);
    _addressController.addListener(_checkForChanges);
    _zipcodeController.addListener(_checkForChanges);
    _countryController.addListener(_checkForChanges);
    _stateController.addListener(_checkForChanges);
    _cityController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    final hasChanges = _firstNameController.text != _user.firstName ||
        _lastNameController.text != _user.lastName ||
        _emailController.text != _user.email ||
        _mobileController.text != (_user.mobileNo ?? '') ||
        _addressController.text != (_user.address ?? '') ||
        _zipcodeController.text != (_user.zipcode ?? '') ||
        _countryController.text != (_user.country ?? '') ||
        _stateController.text != (_user.state ?? '') ||
        _cityController.text != (_user.city ?? '') ||
        _hasNewImage;

    setState(() => _hasChanges = hasChanges);
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        final Uint8List? imageBytes = await ImagePickerWeb.getImageAsBytes();
        if (imageBytes != null) {
          setState(() {
            _pickedImage = imageBytes;
            _hasNewImage = true;
          });
        }
      } else {
        final pickedFile =
            await ImagePicker().pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          setState(() {
            _pickedImage = File(pickedFile.path);
            _hasNewImage = true;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.updateEmail(newEmail);
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw Exception('Failed to update email: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate() || !_hasChanges) return;

    setState(() => _isLoading = true);

    try {
      // Handle image upload if changed
      if (_hasNewImage) {
        String? imageUrl;

        if (kIsWeb) {
          imageUrl = await CloudinaryService.uploadImage(
              _pickedImage as Uint8List, "profiles/${_user.uid}");
        } else {
          imageUrl = await CloudinaryService.uploadImage(
              _pickedImage as File, "profiles/${_user.uid}");
        }

        if (imageUrl != null) {
          _user = _user.copyWith(imageURL: imageUrl);
        }
      }

      // Update email if changed
      if (_emailController.text.trim() != _user.email) {
        await _updateEmail(_emailController.text.trim());
      }

      // Update user data
      _user = _user.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNo: _mobileController.text.trim().isEmpty
            ? null
            : _mobileController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        zipcode: _zipcodeController.text.trim().isEmpty
            ? null
            : _zipcodeController.text.trim(),
        country: _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
      );

      await FirestoreService.updateUserData(_user);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      Navigator.pop(context, _user);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ImageProvider _getProfileImage() {
    if (_hasNewImage) {
      if (kIsWeb) {
        return MemoryImage(_pickedImage as Uint8List);
      } else {
        return FileImage(_pickedImage as File);
      }
    } else if (_user.imageURL != null) {
      return NetworkImage(_user.imageURL!);
    }
    return const AssetImage('assets/images/default_avatar.png');
  }

  bool _shouldShowPlaceholder() {
    return !_hasNewImage && _user.imageURL == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _getProfileImage(),
                        child: _shouldShowPlaceholder()
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextFormField(
                      controller: _firstNameController,
                      label: 'First Name*',
                      validator: (val) =>
                          val!.trim().isEmpty ? 'Required' : null,
                    ),
                    _buildTextFormField(
                      controller: _lastNameController,
                      label: 'Last Name*',
                      validator: (val) =>
                          val!.trim().isEmpty ? 'Required' : null,
                    ),
                    _buildTextFormField(
                      controller: _emailController,
                      label: 'Email*',
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) =>
                          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(val!.trim())
                              ? 'Enter valid email'
                              : null,
                    ),
                    _buildTextFormField(
                      controller: _mobileController,
                      label: 'Mobile No',
                      keyboardType: TextInputType.phone,
                    ),
                    _buildTextFormField(
                      controller: _addressController,
                      label: 'Address',
                      maxLines: 2,
                    ),
                    _buildTextFormField(
                      controller: _zipcodeController,
                      label: 'Zipcode',
                      keyboardType: TextInputType.number,
                    ),
                    _buildTextFormField(
                      controller: _countryController,
                      label: 'Country',
                    ),
                    _buildTextFormField(
                      controller: _stateController,
                      label: 'State',
                    ),
                    _buildTextFormField(
                      controller: _cityController,
                      label: 'City',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _hasChanges ? _updateProfile : null,
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_checkForChanges);
    _lastNameController.removeListener(_checkForChanges);
    _emailController.removeListener(_checkForChanges);
    _mobileController.removeListener(_checkForChanges);
    _addressController.removeListener(_checkForChanges);
    _zipcodeController.removeListener(_checkForChanges);
    _countryController.removeListener(_checkForChanges);
    _stateController.removeListener(_checkForChanges);
    _cityController.removeListener(_checkForChanges);

    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _zipcodeController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}

