import 'package:bcalio/utils/misc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../controllers/contact_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/contact_model.dart';
import '../../models/true_user_model.dart';
import '../../themes/theme.dart';
import '../../widgets/base_widget/custom_loading_indicator.dart';
import '../../widgets/base_widget/custom_snack_bar.dart';
import 'package:intl_phone_field/phone_number.dart';

class AddContactScreen extends StatefulWidget {
  AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxBool isPhoneNumberValid = false.obs;
  final RxBool isNameFieldEnabled = true.obs;
  final RxString fetchedName = ''.obs;
  final RxInt currentStep = 0.obs;
  final UserController userController = Get.find<UserController>();
  final ContactController contactController = Get.find<ContactController>();

  Future<void> checkPhoneNumber(String phone) async {
    debugPrint('checkPhoneNumber called: phone=$phone');
    if (phone.isEmpty) {
      isPhoneNumberValid.value = false;
      isNameFieldEnabled.value = true;
      fetchedName.value = '';
      nameController.clear();
      return;
    }

    final token = await userController.getToken();
    if (token == null || token.isEmpty) {
      showErrorSnackbar("token_error".tr);
      return;
    }

    isLoading.value = true;
    try {
      final users = await userController.fetchUsers(token);
      debugPrint('Fetched users: ${users.length}');
      final user = users.firstWhere(
        (user) {
          if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
            return false;
          }
          final cleanedUserPhone = user.phoneNumber!.replaceAll(RegExp(r'[^0-9]'), '');
          final cleanedInputPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
          debugPrint('Comparing: cleanedUserPhone=$cleanedUserPhone, cleanedInputPhone=$cleanedInputPhone');
          return cleanedUserPhone.endsWith(cleanedInputPhone);
        },
        orElse: () => User(
          id: '',
          email: '',
          name: '',
          image: '',
          phoneNumber: null,
        ),
      );

      if (user.id.isNotEmpty) {
        isPhoneNumberValid.value = true;
        isNameFieldEnabled.value = false;
        fetchedName.value = user.name;
        nameController.text = user.name;
        debugPrint('User found: ${user.name}, ID: ${user.id}');
      } else {
        isPhoneNumberValid.value = false;
        isNameFieldEnabled.value = true;
        fetchedName.value = '';
        nameController.clear();
        debugPrint('No user found for phone: $phone');
      }
    } catch (e) {
      debugPrint('Error in checkPhoneNumber: $e');
      showErrorSnackbar("phone_check_error".tr + e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> checkAndAddContact() async {
    debugPrint('checkAndAddContact called');
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      showErrorSnackbar("empty_phone_error".tr);
      return;
    }

    if (isNameFieldEnabled.value && name.isEmpty) {
      showErrorSnackbar("empty_name_error".tr);
      return;
    }

    isLoading.value = true;
    try {
      final token = await userController.getToken();
      if (token == null || token.isEmpty) {
        showErrorSnackbar("token_error".tr);
        return;
      }

      final users = await userController.fetchUsers(token);
      debugPrint('Fetched users: ${users.length}, phone=$phone');
      final user = users.firstWhere(
        (user) {
          if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
            return false;
          }
          final cleanedUserPhone = user.phoneNumber!.replaceAll(RegExp(r'[^0-9]'), '');
          final cleanedInputPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
          debugPrint('Comparing: cleanedUserPhone=$cleanedUserPhone, cleanedInputPhone=$cleanedInputPhone');
          return cleanedUserPhone.endsWith(cleanedInputPhone);
        },
        orElse: () => User(
          id: '',
          email: '',
          name: '',
          image: '',
          phoneNumber: null,
        ),
      );

      if (user.id.isNotEmpty) {
        final existingContact = contactController.contacts.firstWhere(
          (contact) => contact.id == user.id,
          orElse: () => Contact(
            id: '',
            name: '',
            email: '',
            image: null,
            phoneNumber: null,
          ),
        );
        debugPrint('Existing Contact ID: ${existingContact.id}');
        if (existingContact.id.isNotEmpty) {
          showSuccessSnackbar("contact_already_added".tr);
        } else {
          final contactName = name.isNotEmpty ? name : phone;
          debugPrint('Adding contact with ID: ${user.id}');
          await contactController.addContactToPhone(contactName, phone, '');
            final newContact = Contact(
        id: '',
        name: contactName, // Nom correct
        email: '',
        phoneNumber: phone,
        isPhoneContact: true,
      );
      
      contactController.contacts.add(newContact);
      await contactController.saveContactsToCache();
      showSuccessSnackbar("contact_added_to_phone".tr);
    }
      } else {
        debugPrint('No user found, adding to phone contacts: name=$name, phone=$phone');
        // CORRECTION : Utiliser le nom saisi pour le contact téléphone
        await contactController.addContactToPhone(name, phone, '');
        // Créer un contact avec le nom saisi pour l'application
        final newContact = Contact(
          id: '',
          name: name, // Utiliser le nom saisi
          email: '',
          phoneNumber: phone,
          isPhoneContact: true,
        );
        contactController.contacts.add(newContact);
        await contactController.saveContactsToCache();
        showSuccessSnackbar("contact_added_to_phone".tr);
      }

      contactController.isFirst
          ? contactController.fetchContactsFromApiPhone()
          : contactController.loadCachedContacts();
      Get.offNamed('/allContactsScreen');
    } catch (e) {
      debugPrint('Error adding contact: $e');
      if (e.toString().contains('Contact already added')) {
        showSuccessSnackbar("contact_already_added".tr);
      } else {
        showErrorSnackbar("contact_add_error".tr + e.toString());
      }
    } finally {
      isLoading.value = false;
    }
  }

  FocusNode focusNode = FocusNode();
  PhoneNumber number = PhoneNumber(countryCode: "216", countryISOCode: "TN", number: '');
  final language = Get.locale?.languageCode ?? 'en';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          color: isDarkMode ? kDarkBgColor : kLightPrimaryColor,
        ),
        title: Text(
          "add_contact".tr,
          style: theme.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : kDarkBgColor,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left,
            color: isDarkMode ? Colors.white : kDarkBgColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Obx(() {
              return EasyStepper(
                activeStep: currentStep.value,
                direction: Axis.vertical,
                stepRadius: 20,
                activeStepTextColor: theme.colorScheme.primary,
                finishedStepTextColor: Colors.green,
                activeStepIconColor: theme.colorScheme.primary,
                finishedStepIconColor: Colors.green,
                showLoadingAnimation: false,
                steps: [
                  EasyStep(
                    icon: const Icon(Iconsax.call, size: 24),
                    title: "\n${"step_1".tr}",
                    finishIcon: const Icon(Iconsax.tick_circle),
                    customStep: CircleAvatar(
                      radius: 20,
                      backgroundColor: currentStep.value >= 0
                          ? theme.appBarTheme.backgroundColor
                          : Colors.grey,
                      child: const Icon(Iconsax.call, color: Colors.white),
                    ),
                  ),
                  EasyStep(
                    icon: const Icon(Iconsax.user, size: 24),
                    title: "\n${'step_2'.tr}",
                    finishIcon: const Icon(Iconsax.tick_circle),
                    customStep: CircleAvatar(
                      radius: 20,
                      backgroundColor: currentStep.value >= 1
                          ? theme.appBarTheme.backgroundColor
                          : Colors.grey,
                      child: const Icon(Iconsax.user, color: Colors.white),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),
            Obx(() {
              if (currentStep.value == 0) {
                return _buildPhoneNumberStep(theme, isDarkMode);
              } else {
                return _buildNameStep(theme);
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneNumberStep(ThemeData theme, bool isDarkMode) {
    return Column(
      children: [
        Text(
          "enter_phone_number".tr,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "phone_number_description".tr,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        IntlPhoneField(
          focusNode: focusNode,
          showCountryFlag: false,
          pickerDialogStyle: PickerDialogStyle(
            searchFieldInputDecoration: InputDecoration(
              hintText: "\t\t${"search_country".tr}",
              suffixIcon: Icon(
                Iconsax.search_normal_1,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          decoration: InputDecoration(
            hintText: "phone_number_hint".tr,
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            ),
          ),
          initialCountryCode: "TN",
          languageCode: language,
          onChanged: (phone) {
            debugPrint('Phone number changed: ${phone.completeNumber}');
            number = phone;
            checkPhoneNumber(number.number);
          },
          onCountryChanged: (country) {
            debugPrint('Country changed to: ${country.name}');
          },
          controller: phoneController,
        ),
        const SizedBox(height: 24),
        Obx(() => isLoading.value
            ? CustomLoadingIndicator()
            : ElevatedButton(
                onPressed: () {
                  if (phoneController.text.isNotEmpty) {
                    if (isPhoneNumberValid.value || isNameFieldEnabled.value) {
                      currentStep.value = 1;
                    } else {
                      showErrorSnackbar("invalid_phone_error".tr);
                    }
                  } else {
                    showErrorSnackbar("empty_phone_error".tr);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? kDarkPrimaryColor : kLightPrimaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "next".tr,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildNameStep(ThemeData theme) {
    return Column(
      children: [
        Text(
          "enter_name".tr,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "name_description".tr,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Obx(() {
          return TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: "name".tr,
              hintText: "enter_name_hint".tr,
              prefixIcon: const Icon(Iconsax.user),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              enabled: isNameFieldEnabled.value,
            ),
          );
        }),
        const SizedBox(height: 24),
        Obx(() => isLoading.value
            ? CustomLoadingIndicator()
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      currentStep.value = 0;
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "back".tr,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: checkAndAddContact,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.appBarTheme.backgroundColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "save".tr,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              )),
      ],
    );
  }
}