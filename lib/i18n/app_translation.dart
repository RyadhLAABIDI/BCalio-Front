import 'package:get/get.dart';

class AppTranslation extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'fr_FR': {
          'retry': 'Réessayer',
          'add': 'Ajouter',
          'chat_bot_clear': 'Effacer la conversation',
          'chat_bot_close': 'Fermer',
          'welcome_message': 'Vous connecter au monde avec facilité et style.',
          'feature_secure_title': 'Conversations sécurisées',
          'feature_secure_description':
              'Votre vie privée est notre priorité. Tous les messages sont cryptés de bout en bout.',
          'feature_support_title': 'Support multiplateforme',
          'feature_support_description':
              'Restez connecté sur tous vos appareils.',
          'feature_connected_title': 'Restez connecté',
          'feature_connected_description':
              'Discutez avec vos proches ou collaborez avec votre équipe.',
          'agree_and_continue': 'ACCEPTER ET CONTINUER',
          'footer_powered_by': 'Propulsé par Bacallio Technologies',
          'verify_phone': 'Vérifiez votre téléphone',
          'verification_message':
              'Bacalio enverra un SMS pour vérifier votre numéro de téléphone. Des frais d’opérateur peuvent s’appliquer.',
          'your_phone_number': 'Votre numéro de téléphone',
          'phone_number_hint': 'Numéro de téléphone',
          'next': 'SUIVANT',
          'invalid_phone_number':
              'Entrez un numéro de téléphone valide (au moins 6 chiffres).',
          'otp_verification': 'Vérification OTP',
          'enter_otp_message':
              'Entrez le code à 6 chiffres envoyé à votre téléphone.',
          'clear_code': 'Effacer le code',
          'verify': 'Vérifier',
          'invalid_otp_message':
              'Erreur, Entrez un code OTP valide de 6 chiffres.',
          'otp_verified_message': 'Succès, OTP vérifié !',
          'invalid_otp_retry': 'Erreur, OTP invalide. Réessayez.',
          'create_profile': 'Créez votre profil',
          'enter_name': 'Veuillez entrer votre nom.',
          'enter_your_name': 'Entrez votre nom',
          'your_name': 'Votre nom',
          'chats': 'Discussions',
          'calls': 'Appels',
          'search_chats': 'Rechercher des discussions',
          'settings': 'Paramètres',
          'phone_number': 'Numéro de téléphone',
          'theme': 'Thème',
          'dark_mode': 'Mode sombre',
          'language': 'Langue',
          'success': 'Succès',
          'error': 'Erreur',
          'no_results_found': 'Aucun résultat trouvé',
          'no_contacts_match': 'Aucun contact ne correspond à votre recherche.',
          'no_chats_yet': 'Pas encore de discussions',
          'type_a_message': 'Tapez un message...',
          'online': 'En ligne',
          'Chats': 'Discussions',
          'Calls': 'Appels',
          'Settings': 'Paramètres',
          'New Group': 'Nouveau groupe',
          'Notice': 'Avis',
          'All Contacts': 'Tous les contacts',
          'Search for a contact or select one from the list below.':
              'Recherchez un contact ou sélectionnez-en un dans la liste ci-dessous.',
          'Search Contacts': 'Rechercher des contacts',
          'No contacts match your search.':
              'Aucun contact ne correspond à votre recherche.',
          'Unknown': 'Inconnu',
          'No Phone Number': 'Pas de numéro de téléphone',
          'Create Group Chat': 'Créer un chat de groupe',
          'Select contacts to create a group chat.':
              'Sélectionnez des contacts pour créer un chat de groupe.',
          'Create Group': 'Créer un groupe',
          'Profile': 'Profil',
          'Call': 'Appel',
          'Video Call': 'Appel Vidéo',
          'Message': 'Message',
          'Add Contact': 'Ajouter un contact',
          'Phone Number': 'Numéro de téléphone',
          'About': 'À propos',
          'Joined in January 2023': 'Inscrit en janvier 2023',
          'An error occurred.': 'Une erreur s\'est produite.',
          'No recent calls': 'Aucun appel récent',
          'Recent': 'Récent',
          "Welcome Back!": "Bon retour!",
          "Login to your account": "Connectez-vous à votre compte",
          "Email": "Email",
          "Enter your email": "Entrez votre email",
          "Password": "Mot de passe",
          "Enter your password": "Entrez votre mot de passe",
          "Forgot Password?": "Mot de passe oublié?",
          "Login": "Se connecter",
          "Don't have an account?": "Vous n'avez pas de compte?",
          "Sign Up": "S'inscrire",
          "Error,Please fill in all fields.":
              "Erreur, veuillez remplir tous les champs.",
          "Create Profile": "Créer un profil",
          "Fill in the details below to create your profile.":
              "Remplissez les détails ci-dessous pour créer votre profil.",
          "Name": "Nom",
          "Enter your name": "Entrez votre nom",
          "By creating a profile, you agree to our Terms & Conditions.":
              "En créant un profil, vous acceptez nos termes et conditions.",
          "Please fill all fields": "Veuillez remplir tous les champs",
          "failed_to_retrieve_token":
              "Échec de la récupération du jeton. Veuillez vous reconnecter.",
          "failed_to_retrieve_token_2": "Échec de la récupération du jeton.",
          "sending_status": "Statut d'envoi",
          "recording": "Enregistrement...",
          "attach_image": "Joindre une image",
          "attach_video": "Joindre une vidéo",
          "record_voice_message": "Enregistrer un message vocal",
          "allow_notifications": "Autoriser les notifications",
          "allow_contacts": "Autoriser les contacts",
          "group_details": "Détails du groupe",
          "group_name": "Nom du groupe",
          "tap_to_upload_logo": "Appuyez pour télécharger le logo",
          "cancel": "Annuler",
          "create": "Créer",
          "error_failed_to_create_group": "Échec de la création du groupe",
          "add_contact": "Ajouter un contact",
          "search_by_phone_number": "Recherche par numéro de téléphone",
          "search_for_a_user_and_add_them_to_your_contacts":
              "Recherchez un utilisateur et ajoutez-le à vos contacts.",
          "enter_phone_number_in_the_search_bar_above":
              "Entrez un numéro de téléphone dans la barre de recherche ci-dessus.",
          "no_users_found": "Aucun utilisateur trouvé.",
          "please_try_another_search_term":
              "Veuillez essayer un autre terme de recherche.",
          "error_failed_to_add_contact": "Erreur, Échec d'ajouter le contact",
          "success_contact_added":
              "Succès, contact a été ajouté à vos contacts.",
          "Logout": "Déconnexion",
          "Update Profile": "Mettre à jour le profil",
          "Update your profile details below.":
              "Mettez à jour les détails de votre profil ci-dessous.",
          "Tell us about yourself": "Parlez-nous de vous",
          "Changes will be reflected immediately.":
              "Les modifications seront immédiatement reflétées.",
          'enter_phone_number': 'Entrer le Numéro de Téléphone',
          'phone_number_description':
              'Veuillez entrer le numéro de téléphone du contact que vous souhaitez ajouter. Si le numéro de téléphone est déjà enregistré, le champ du nom sera automatiquement rempli.',
          'enter_phone_hint': 'Entrez votre numéro de téléphone',
          'name_description':
              'Veuillez entrer le nom du contact. Si le numéro de téléphone est déjà enregistré, le champ du nom sera pré-rempli et désactivé.',
          'name': 'Nom',
          'enter_name_hint': 'Entrez votre nom',
          'back': 'Retour',
          'save': 'Enregistrer',
          'token_error':
              'Échec de la récupération du token. Veuillez vous reconnecter.',
          'phone_check_error':
              'Échec de la vérification du numéro de téléphone : ',
          'empty_phone_error': 'Veuillez entrer un numéro de téléphone.',
          'empty_name_error': 'Veuillez entrer un nom.',
          'contact_already_added': 'Contact déjà ajouté',
          'contact_added_success': 'Contact ajouté avec succès !',
          'contact_added_to_phone': 'Contact ajouté au téléphone !',
          'contact_add_error': 'Échec de l\'ajout du contact : ',
          'step_1': 'Étape 1',
          'step_2': 'Étape 2',
          'hi_how_can_i_assist_you?': 'Salut! Comment puis-je vous aider?',
          'forgot_password': 'Mot de passe oublié',
          "failed_to_send_OTP_Please_try_again.":
              "Échec de l'envoi de l'OTP. Veuillez réessayer.",
          "OTP_verified_successfully!": "OTP vérifié avec succès!",
          "invalid_OTP_please_try_again.": "OTP invalide. Veuillez réessayer.",
          "invalid_OTP": "OTP invalide",
          "new_password": 'Nouveau mot de passe',
          "confirm_password": "Confirmez le mot de passe",
          "enter_new_password": "Entrez le nouveau mot de passe",
          "Re-enter_your_new_password": "Re-entrez votre nouveau mot de passe",
          "please_fill_all_fields": "Veuillez remplir tous les champs",
          "Password_must_be_at_least_8_characters_long_and_contain_uppercase_lowercase_letters_and_numbers":
              "Le mot de passe doit comporter au moins 8 caractères et contenir des lettres majuscules, des lettres minuscules et des chiffres",
          "passwords_do_not_match": "Les mots de passe ne correspondent pas",
          "password_updated_successfully":
              "Mot de passe mis à jour avec succès",
          "error_failed_to_update_password":
              "Échec de la mise à jour du mot de passe",
          "failed_to_send_OTP._please_try_again.":
              "Échec de l'envoi de l'OTP. Veuillez réessayer.",
          'Are you sure you want to log out?':
              'Êtes-vous sûr de vouloir vous déconnecter?',
          'Yes': 'Oui',
          'No': 'NoN',
          "call_failed": "Échec de l'appel",
          'une_erreur_inattendue_s_est_produite._veuillez_réessayer.':
              'Une erreur inattendue s\'est produite. Veuillez réessayer.',
          "The user has not installed the app ":
              "L'utilisateur n'a pas installé l'application.",
          "No user has been selected for the call. Please check the invitees list.":
              "Aucun utilisateur n'a été sélectionné pour l'appel. Veuillez vérifier la liste des invités.",
          'Un appel est déjà en cours. Veuillez réessayer plus tard.':
              'Un appel est déjà en cours. Veuillez réessayer plus tard.',
          "Please check your credentials":
              "Veuillez vérifier vos informations d'identification",
          "Failed to log out. Please try again.":
              "Échec de la déconnexion. Veuillez réessayer.",
          "User already exist": "L'utilisateur existe déjà",
          'Failed to update profile. Please try again.':
              'Échec de la mise à jour du profil. Veuillez réessayer.',
          'Failed to fetch messages. Please try again.':
              'Échec de la récupération des messages. Veuillez réessayer.',
          "Failed to get AI response":
              "Échec de l'obtention de la réponse de l'IA",
          'remember_me': 'Se souvenir de moi',
          "texte_copié": "Texte copié",
          "image_was_sent": "L'image a été envoyée",
          "audio_message_was_sent": "Le message audio a été envoyé",
          "video_message_was_sent": "Le message vidéo a été envoyé",
          "please_provide_a_group_name.": "Veuillez fournir un nom de groupe.",
          "this_contact_n'est_pas_encore_sur_B-callio.Invitez-le_à_nous_rejoindre !":
              "Ce contact n'est pas encore sur B-callio. Invitez-le à nous rejoindre !",
          "inviter_par_sms": "Inviter par SMS",
          "pas_maintenant": "Pas maintenant",
          "anglais": "Anglais",
          "français": "Français",
          "arabic": "Arabe",
          "no_messages_yet": "Pas encore de messages",
          "un_de_vos_contacts_n_a_pas_encore_utilisé_application.":
              "Un de vos contacts n\'a pas encore utilisé l\'application.",
          "success_invitation_sent_to_contact":
              "Succès ! Invitation envoyée au contact.",
          "error_failed_to_send_invitation_to_contact":
              "Erreur ! Échec de l'envoi de l'invitation au contact.",
          "No Name Available": "Aucun nom disponible",
          "search_country": "Rechercher un pays",
          "camera": "Caméra",
          "gallery": "Galerie",
          "permission_requise": "Permission requise",
          "Vous devez autoriser l'accès à la caméra dans les paramètres.":
              "Vous devez autoriser l'accès à la caméra dans les paramètres.",
          "Vous devez autoriser l'accès à la galerie dans les paramètres.":
              "Vous devez autoriser l'accès à la galerie dans les paramètres.",
          "Vous devez autoriser l'accès au microphone dans les paramètres.":
              "Vous devez autoriser l'accès au microphone dans les paramètres.",
          "Ouvrir les paramètres": "Ouvrir les paramètres",
          "A screenshot has been taken!": "Une capture d'écran a été prise!",
          "Location": "Emplacement",
          "Chat": "Discussions",
          "has entered the chat!": "est entré dans la discussion!",
          'Tap a marker to show route, double-tap for details':
              'Appuyez sur un marqueur pour afficher l\'itinéraire, double-cliquez pour plus de détails',
          "Delete Conversation": "Supprimer la conversation",
          "Are you sure you want to delete this conversation?":
              "Êtes-vous sûr de vouloir supprimer cette conversation?",
          "Delete": "Supprimer",
          'Copied': 'Copié',
          'Message copied to clipboard': 'Message copié dans le presse-papiers',
          'Copy': 'Copier',
          'Delete Message': 'Supprimer le message',
          "Are you sure you want to delete this message?":
              "Êtes-vous sûr de vouloir supprimer ce message?",
          'user_entered': '[système] :name a rejoint la discussion !',

          "clear_conversation": "Effacer la conversation",
  "clear_conversation_confirmation": "Voulez-vous vraiment supprimer toute la conversation?",
  "clear": "Effacer",
  
  "conversation_cleared": "Conversation effacée!",
  "conversation_empty": "Commencez une nouvelle conversation",
  // Appels / toasts / statuts
      'a rejoint l’appel': 'a rejoint l’appel',
      'Ne répond pas': 'Ne répond pas',
      'Occupé': 'Occupé',
      'Appel terminé': 'Appel terminé',
      'Waiting for participants…': 'En attente des participants…',
      'Me': 'Moi',
      'Calling…': 'Appel en cours…',
      'In group call…': 'En appel de groupe…',
      'In call…': 'En appel…',
      'Group video call': 'Appel vidéo de groupe',
      'Group audio call': 'Appel audio de groupe',
      'Video call': 'Appel vidéo',
      'Audio call': 'Appel audio',

      // Chatbot modal
      'BCalio-AI': 'BCalio-AI',
      'Hi! I\'m your AI assistant': 'Salut ! Je suis votre assistant IA',
      'Ask me anything, and I\'ll help you find answers':
          'Posez-moi vos questions, je vous aiderai à trouver des réponses',
      

      // Dialog nettoyage conversation
      
       // CallLogScreen
      'Journal d’appel': 'Journal d’appel',
      'Effacer l’historique': 'Effacer l’historique',
      'Effacer l’historique ?': 'Effacer l’historique ?',
      'Cette action est irréversible.': 'Cette action est irréversible.',
      'Annuler': 'Annuler',
      'Effacer': 'Effacer',
      'Tous': 'Tous',
      'Manqués': 'Manqués',
      'Entrants': 'Entrants',
      'Sortants': 'Sortants',
      'Supprimer': 'Supprimer',
      'Aucun appel pour le moment.': 'Aucun appel pour le moment.',
      'Les appels récents apparaîtront ici.': 'Les appels récents apparaîtront ici.',

      // ChatRoomAppBar / presence
      'Vu à l’instant': 'Vu à l’instant',
      'Vu il y a': 'Vu il y a',
      'min': 'min',
      'h': 'h',
      'Vu le': 'Vu le',
      'Hors ligne': 'Hors ligne',
      'En ligne': 'En ligne',
      'en ligne': 'en ligne',

      // NavigationScreen labels
      
      'Contact': 'Contacts',
      

      // SettingsScreen
      'Statut: En ligne': 'Statut: En ligne',
      'Statut: Hors ligne': 'Statut: Hors ligne',
      'Vos contacts vous voient “en ligne”.': 'Vos contacts vous voient “en ligne”.',
      'Vous apparaissez hors ligne (mode invisible).': 'Vous apparaissez hors ligne (mode invisible).',
      'Visible': 'Visible',
      'Invisible': 'Invisible',
      'Mon QR': 'Mon QR',
      'Affiche ton code QR (valide ~30 jours) pour être ajouté rapidement.':
          'Affiche ton code QR (valide ~30 jours) pour être ajouté rapidement.',
      'Ouvrir': 'Ouvrir',
      'Connexion Web': 'Connexion Web',
      'Scanner le QR affiché sur le site pour ouvrir ta session.':
          'Scanner le QR affiché sur le site pour ouvrir ta session.',
      'Scanner': 'Scanner',
       
'Sans expiration': 'Sans expiration',
'Expiré • Régénérer': 'Expiré • Régénérer',
'Expire dans': 'Expire dans',
'j': 'j',

'm': 'm',
'Régénérer': 'Régénérer',
'Aucun QR': 'Aucun QR',

'Scanner — Connexion Web': 'Scanner — Connexion Web',
'Vous devez être connecté dans l’app.': 'Vous devez être connecté dans l’app.',
'Connecté': 'Connecté',
'Retourne sur le Web — tu es connecté 👍': 'Retourne sur le Web — tu es connecté 👍',
'Échec': 'Échec',
'QR scanné.\nVérifie le navigateur Web.': 'QR scanné.\nVérifie le navigateur Web.',
'Terminer': 'Terminer',


'Ajouter via QR': 'Ajouter via QR',
'Échec QR': 'Échec QR',
'inconnu': 'inconnu',
'QR invalide': 'QR invalide',
'contactId manquant': 'contactId manquant',
'Utilisateur trouvé, mais son numéro n\'a pas été récupéré.\nAjoute-le manuellement ou complète le numéro.':
  'Utilisateur trouvé, mais son numéro n\'a pas été récupéré.\nAjoute-le manuellement ou complète le numéro.',
'Contact ajouté': 'Contact ajouté',

'Succès, invitation envoyée à': 'Succès, invitation envoyée à',
'Erreur, échec de l\'envoi de l\'invitation à': 'Erreur, échec de l\'envoi de l\'invitation à',
'Échec de la sélection de l\'image': 'Échec de la sélection de l\'image',
'Échec de l\'envoi de l\'invitation': 'Échec de l\'envoi de l\'invitation',
'Nom du groupe': 'Nom du groupe',
'Veuillez entrer un nom de groupe': 'Veuillez entrer un nom de groupe',
'Créer': 'Créer',
'N/A': 'N/A',

'Contacts enregistrés': 'Contacts enregistrés',
'Contacts non enregistrés': 'Contacts non enregistrés',

'try_different_keywords': 'Essayez avec d’autres mots-clés',
  'swipe_to_decline': 'Glisser pour refuser',
  'swipe_to_answer': 'Glisser pour répondre',
  'scan_qr': 'Scanner QR',
  'my_qr': 'Mon QR',
  'connection_issue': 'Problème de connexion',
  'check_connection': 'Vérifiez votre connexion internet ou réessayez plus tard.',
  // ======= Onboarding Lang =======
          'choose_language': 'Choisis ta langue',
          'change_anytime_hint': 'Tu pourras la modifier à tout moment dans Réglages → Langue, en bas.',
          'app_language': 'Langue de l’application',
          'tip_change_later': 'Astuce : tu peux aussi changer la langue plus tard dans Réglages.',
          'continue_btn': 'Continuer',
          'lang_english': 'Anglais',
          'lang_french': 'Français',
          'lang_arabic': 'Arabe',

          'rooms': 'Rooms',
  
  'room_id_optional': 'ID de room (optionnel)',
  'join_create': 'Rejoindre / Créer',
  'instructions': 'Instructions',
  'swipe_up': 'Balayez vers le haut',
  'quick_guide': 'Guide rapide',
  'bullet_name': 'Entrez votre nom — il s’affiche dans la room.',
  'bullet_join': 'Pour rejoindre : collez un ID de room reçu.',
  'bullet_create': 'Pour créer : laissez vide, puis « Rejoindre / Créer ».',
  'bullet_share': 'Partagez l’ID après entrée pour inviter quelqu’un.',
  'tip_more': 'Astuce : gardez ce sheet tiré vers le haut pour voir plus ✨',

  
  'Room': 'Room',

  'Secure Encryption': 'Chiffrement sécurisé',
          'All your data is end-to-end encrypted':
              'Toutes vos données sont chiffrées de bout en bout',
          'Cloud Sync': 'Synchronisation cloud',
          'Access your data from any device':
              'Accédez à vos données depuis n’importe quel appareil',
          'Lightning Fast': 'Ultra rapide',
          'Optimized for maximum performance':
              'Optimisé pour des performances maximales',
  

        },
        'ar_AR': {

          // ======= Onboarding Lang =======
          'choose_language': 'اختر لغتك',
          'change_anytime_hint': 'يمكنك تغييرها في أي وقت من الإعدادات → اللغة أسفل الشاشة.',
          'app_language': 'لغة التطبيق',
          'tip_change_later': 'نصيحة: يمكنك أيضًا تغيير اللغة لاحقًا من الإعدادات.',
          'continue_btn': 'متابعة',
          'lang_english': 'الإنجليزية',
          'lang_french': 'الفرنسية',
          'lang_arabic': 'العربية',
          'retry': 'إعادة المحاولة',
          'add': 'إضافة',
          "clear_conversation": "مسح المحادثة",
  "clear_conversation_confirmation": "هل أنت متأكد أنك تريد حذف المحادثة بالكامل؟",
  "clear": "مسح",
  
  "conversation_cleared": "تم مسح المحادثة!",
  "conversation_empty": "ابدأ محادثة جديدة",
          'chat_bot_clear': 'مسح الدردشة',
          'chat_bot_close': 'إغلاق',
          'welcome_message': 'توصيلك بالعالم بسهولة وأناقة.',
          'feature_secure_title': 'محادثات آمنة',
          'feature_secure_description':
              'خصوصيتك هي أولويتنا. جميع الرسائل مشفرة تمامًا.',
          'feature_support_title': 'دعم متعدد المنصات',
          'feature_support_description':
              'ابق على اتصال بسلاسة عبر جميع أجهزتك.',
          'feature_connected_title': 'ابق على اتصال',
          'feature_connected_description': 'تواصل مع أحبائك أو تعاون مع فريقك.',
          'agree_and_continue': 'موافق ومتابعة',
          'footer_powered_by': 'مدعوم من Bacallio Technologies',
          'verify_phone': 'تحقق من هاتفك',
          'verification_message':
              'سيرسل B-callio رسالة SMS للتحقق من رقم هاتفك. قد يتم تطبيق رسوم الناقل.',
          'your_phone_number': 'رقم هاتفك',
          'phone_number_hint': 'رقم الهاتف',
          'next': 'التالي',
          'invalid_phone_number': 'أدخل رقم هاتف صالح (6 أرقام على الأقل).',
          'otp_verification': 'التحقق من OTP',
          'enter_otp_message':
              'أدخل رمز التحقق المكون من 6 أرقام المرسل إلى هاتفك.',
          'clear_code': 'مسح الرمز',
          'verify': 'تحقق',
          'invalid_otp_message': 'خطأ، أدخل رمز OTP صالح مكون من 6 أرقام.',
          'otp_verified_message': 'تم التحقق بنجاح!',
          'invalid_otp_retry': 'خطأ، رمز OTP غير صالح. حاول مرة أخرى.',
          'create_profile': 'قم بإنشاء ملفك الشخصي',
          'enter_name': 'يرجى إدخال اسمك.',
          'enter_your_name': 'أدخل اسمك',
          'your_name': 'اسمك',
          'chats': 'الدردشات',
          'calls': 'المكالمات',
          'search_chats': 'بحث في الدردشات',
          'settings': 'الإعدادات',
          'phone_number': 'رقم الهاتف',
          'theme': 'السمة',
          'dark_mode': 'الوضع الداكن',
          'language': 'لغة',
          'success': 'نجاح',
          'error': 'خطأ',
          'no_results_found': 'لم يتم العثور على نتائج',
          'no_contacts_match': 'لا توجد جهات اتصال تطابق بحثك.',
          'no_chats_yet': 'لا توجد محادثات حتى الآن',
          'type_a_message': 'اكتب رسالة...',
          'online': 'متصل',
          'Chats': 'الدردشات',
          'Calls': 'المكالمات',
          'Settings': 'الإعدادات',
          'New Group': 'مجموعة جديدة',
          'Notice': 'إشعار',
          'All Contacts': 'جميع جهات الاتصال',
          'Search for a contact or select one from the list below.':
              'ابحث عن جهة اتصال أو اختر واحدة من القائمة أدناه.',
          'Search Contacts': 'بحث عن جهات الاتصال',
          'No contacts match your search.': 'لا توجد جهات اتصال تطابق بحثك.',
          'Unknown': 'غير معروف',
          'No Phone Number': 'لا يوجد رقم هاتف',
          'Create Group Chat': 'إنشاء مجموعة دردشة',
          'Select contacts to create a group chat.':
              'اختر جهات الاتصال لإنشاء مجموعة دردشة.',
          'Create Group': 'إنشاء مجموعة',
          'Profile': 'الملف الشخصي',
          'Call': 'اتصال',
          'Video Call': 'مكالمة فيديو',
          'Message': 'رسالة',
          'Add Contact': 'إضافة جهة اتصال',
          'Phone Number': 'رقم الهاتف',
          'About': 'حول',
          'Joined in January 2023': 'انضم في يناير 2023',
          'An error occurred.': 'حدث خطأ.',
          'No recent calls': 'لا توجد مكالمات حديثة',
          'Recent': 'الأخيرة',
          "Welcome Back!": "مرحبًا بعودتك!",
          "Login to your account": "تسجيل الدخول إلى حسابك",
          "Email": "البريد الإلكتروني",
          "Enter your email": "أدخل بريدك الإلكتروني",
          "Password": "كلمة المرور",
          "Enter your password": "أدخل كلمة المرور",
          "Forgot Password?": "نسيت كلمة المرور؟",
          "Login": "تسجيل الدخول",
          "Don't have an account?": "لا تمتلك حساب؟",
          "Sign Up": "إنشاء حساب",
          "Error,Please fill in all fields.": "خطأ، يرجى ملء جميع الحقول.",
          "Create Profile": "إنشاء الملف الشخصي",
          "Fill in the details below to create your profile.":
              "املأ التفاصيل أدناه لإنشاء ملفك الشخصي.",
          "Name": "الاسم",
          "Enter your name": "أدخل اسمك",
          "By creating a profile, you agree to our Terms & Conditions.":
              "بإنشاء ملفك الشخصي، فإنك توافق على شروطنا وأحكامنا.",
          "Please fill all fields": "يرجى ملء جميع الحقول",
          "failed_to_retrieve_token":
              "فشل في استرجاع الرمز المميز. يرجى تسجيل الدخول مرة أخرى.",
          "failed_to_retrieve_token_2": "فشل في استرجاع الرمز المميز.",
          "sending_status": "حالة الإرسال",
          "recording": "جاري التسجيل...",
          "attach_image": "إرفاق صورة",
          "attach_video": "إرفاق فيديو",
          "record_voice_message": "تسجيل رسالة صوتية",
          "allow_notifications": "السماح بالإشعارات",
          "allow_contacts": "السماح بالاتصال",
          "group_details": "تفاصيل المجموعة",
          "group_name": "اسم المجموعة",
          "tap_to_upload_logo": "اضغط لتحميل الشعار",
          "cancel": "إلغاء",
          "create": "إنشاء",
          "error_failed_to_create_group": "فشل في إنشاء المجموعة",
          "add_contact": "إضافة جهة اتصال",
          "search_by_phone_number": "البحث بواسطة رقم الهاتف",
          "search_for_a_user_and_add_them_to_your_contacts":
              "ابحث عن مستخدم وأضفه إلى جهات الاتصال الخاصة بك.",
          "enter_phone_number_in_the_search_bar_above":
              "أدخل رقم هاتف في شريط البحث أعلاه.",
          "no_users_found": "لم يتم العثور على مستخدمين.",
          "please_try_another_search_term": "يرجى محاولة مصطلح بحث آخر.",
          "error_failed_to_add_contact": "خطأ، فشل في إضافة جهة الاتصال",
          "success_contact_added":
              "نجاح، تم إضافة الاتصال إلى جهات الاتصال الخاصة بك.",
          "Logout": "تسجيل الخروج",
          "Update Profile": "تحديث الملف الشخصي",
          "Update your profile details below.":
              "قم بتحديث تفاصيل ملفك الشخصي أدناه.",
          "Tell us about yourself": "أخبرنا عن نفسك",
          "Changes will be reflected immediately.":
              "سيتم تطبيق التغييرات على الفور.",
          'enter_phone_number': 'أدخل رقم الهاتف',
          'phone_number_description':
              'الرجاء إدخال رقم الهاتف للجهة التي تريد إضافتها. إذا كان رقم الهاتف مسجلًا بالفعل، سيتم ملء حقل الاسم تلقائيًا.',
          'enter_phone_hint': 'أدخل رقم هاتفك',
          'name_description':
              'الرجاء إدخال اسم الجهة. إذا كان رقم الهاتف مسجلًا بالفعل، سيتم ملء حقل الاسم مسبقًا وتعطيله.',
          'name': 'الاسم',
          'enter_name_hint': 'أدخل اسمك',
          'back': 'رجوع',
          'save': 'حفظ',
          'token_error': 'فشل في استرداد الرمز. يرجى تسجيل الدخول مرة أخرى.',
          'phone_check_error': 'فشل في التحقق من رقم الهاتف: ',
          'empty_phone_error': 'الرجاء إدخال رقم هاتف.',
          'empty_name_error': 'الرجاء إدخال اسم.',
          'contact_already_added': 'تمت إضافة الجهة بالفعل',
          'contact_added_success': 'تمت إضافة الجهة بنجاح!',
          'contact_added_to_phone': 'تمت إضافة الجهة إلى الهاتف!',
          'contact_add_error': 'فشل في إضافة الجهة: ',
          'step_1': 'الخطوة 1',
          'step_2': 'الخطوة 2',
          'hi_how_can_i_assist_you?': 'مرحبًا! كيف يمكنني مساعدتك؟',
          'forgot_password': 'نسيت كلمة المرور',
          "failed_to_send_OTP_Please_try_again.":
              "فشل في إرسال OTP. يرجى المحاولة مرة أخرى.",
          "OTP_verified_successfully!": "تم التحقق من OTP بنجاح!",
          "invalid_OTP_please_try_again.":
              "OTP غير صالح. يرجى المحاولة مرة أخرى.",
          "invalid_OTP": "OTP غير صالح",
          'new_password': 'كلمة المرور الجديدة',
          'confirm_password': 'تأكيد كلمة المرور',
          'enter_new_password': 'أدخل كلمة المرور الجديدة',
          "Re-enter_your_new_password": "أعد إدخال كلمة المرور الجديدة",
          "please_fill_all_fields": "يرجى ملء جميع البيانات",
          "Password_must_be_at_least_8_characters_long_and_contain_uppercase_lowercase_letters_and_numbers":
              "يجب أن تكون كلمة المرور على الأقل 8 أحرف وتحتوي على أحرف كبيرة وصغيرة وأرقام",
          "passwords_do_not_match": "كلمات المرور غير متطابقة",
          "password_updated_successfully": "تم تحديث كلمة المرور بنجاح",
          "error_failed_to_update_password": "فشل تحديث كلمة المرور",
          "failed_to_send_OTP._please_try_again.":
              "فشل في إرسال OTP. يرجى المحاولة مرة أخرى.",
          'Are you sure you want to log out?':
              'هل أنت متأكد أنك تريد تسجيل الخروج؟',
          'Yes': 'نعم',
          'No': 'لا',
          "call_failed": "فشل الاتصال",
          'une_erreur_inattendue_s_est_produite._veuillez_réessayer.':
              "حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.",
          "The user has not installed the app ":
              "لم يقم المستخدم بتثبيت التطبيق.",
          "No user has been selected for the call. Please check the invitees list.":
              "لم يتم تحديد أي مستخدم للمكالمة. يرجى التحقق من قائمة الدعوات.",
          'Un appel est déjà en cours. Veuillez réessayer plus tard.':
              " هناك مكالمة قائمة بالفعل. يرجى المحاولة مرة أخرى في وقت لاحق.",
          "Please check your credentials":
              "يرجى التحقق من بيانات الاعتماد الخاصة بك",
          'Failed to log out. Please try again.':
              'فشل تسجيل الخروج. يرجى المحاولة مرة أخرى.',
          "User already exist": "المستخدم موجود بالفعل",
          'Failed to update profile. Please try again.':
              'فشل تحديث الملف الشخصي. يرجى المحاولة مرة أخرى.',
          'Failed to fetch messages. Please try again.':
              'فشل جلب الرسائل. يرجى المحاولة مرة أخرى.',
          "Failed to get AI response":
              "فشل في الحصول على استجابة الذكاء الاصطناعي",
          'remember_me': 'تذكرني',
          "texte_copié": "تم نسخ النص",
          "image_was_sent": "تم إرسال الصورة",
          "audio_message_was_sent": "تم إرسال رسالة الصوت",
          "video_message_was_sent": "تم إرسال رسالة الفيديو",
          "please_provide_a_group_name.": "يرجى تقديم إسم المجموعة.",
          "this_contact_n'est_pas_encore_sur_B-callio.Invitez-le_à_nous_rejoindre !":
              "هذا الاتصال غير موجود على B-callio بعد. قم بدعوته للانضمام إلينا!",
          "inviter_par_sms": "دعوة بالرسالة النصية",
          "pas_maintenant": "لاحقا",
          "anglais": "الإنجليزية",
          "français": "الفرنسية",
          "arabic": "العربية",
          "no_messages_yet": "لا توجد رسائل بعد",
          "un_de_vos_contacts_n_a_pas_encore_utilisé_application.":
              "أحد جهات الاتصال الخاصة بك لم يستخدم التطبيق بعد.",
          "success_invitation_sent_to_contact":
              "نجاح! تم إرسال الدعوة إلى جهة الاتصال.",
          "error_failed_to_send_invitation_to_contact":
              "خطأ! فشل في إرسال الدعوة إلى جهة الاتصال.",
          "No Name Available": "لا يوجد اسم متاح",
          "search_country": "ابحث عن البلد",
          "camera": "الكاميرا",
          "gallery": "معرض الصور",
          "permission_requise": "الإذن مطلوب",
          "Vous devez autoriser l'accès à la galerie dans les paramètres.":
              "يجب عليك السماح بالوصول إلى المعرض في الإعدادات.",
          "Vous devez autoriser l'accès à la caméra dans les paramètres.":
              "يجب عليك السماح بالوصول إلى الكاميرا في الإعدادات.",
          "Vous devez autoriser l'accès au microphone dans les paramètres.":
              "يجب عليك السماح بالوصول إلى الميكروفون في الإعدادات.",
          "Ouvrir les paramètres": "فتح الإعدادات",
          "A screenshot has been taken!": "تم التقاط لقطة شاشة!",
          "Location": "الموقع",
          "Chat": "الدردشة",
          "Contact": "جهة الاتصال",
          "has entered the chat!": "دخل الدردشة!",
          'Tap a marker to show route, double-tap for details':
              "اضغط على العلامة لإظهار المسار، اضغط مرتين للحصول على التفاصيل",
          "Delete Conversation": "حذف المحادثة",
          "Are you sure you want to delete this conversation?":
              "هل أنت متأكد أنك تريد حذف هذه المحادثة؟",
          "Delete": "حذف",
          'Copied': 'تم النسخ',
          'Message copied to clipboard': 'تم نسخ الرسالة إلى الحافظة',
          'Copy': 'نسخ',
          'Delete Message': 'حذف الرسالة',
          "Are you sure you want to delete this message?":
              "هل أنت متأكد أنك تريد حذف هذه الرسالة؟",
          'user_entered': '[النظام] :name انضم إلى المحادثة!',
          // Calls / toasts / statuses
      'a rejoint l’appel': 'انضم إلى المكالمة',
      'Ne répond pas': 'لا يجيب',
      'Occupé': 'مشغول',
      'Appel terminé': 'انتهت المكالمة',
      'Waiting for participants…': 'في انتظار المشاركين…',
      'Me': 'أنا',
      'Calling…': 'جاري الاتصال…',
      'In group call…': 'في مكالمة جماعية…',
      'In call…': 'في مكالمة…',
      'Group video call': 'مكالمة فيديو جماعية',
      'Group audio call': 'مكالمة صوتية جماعية',
      'Video call': 'مكالمة فيديو',
      'Audio call': 'مكالمة صوتية',

      // Chatbot modal
      'BCalio-AI': 'BCalio-AI',
      'Hi! I\'m your AI assistant': 'مرحبًا! أنا مساعدك الذكي',
      'Ask me anything, and I\'ll help you find answers':
          'اسألني أي شيء وسأساعدك في إيجاد الإجابات',
     
      // Clear dialog
      
      
       // CallLogScreen
      'Journal d’appel': 'سجل المكالمات',
      'Effacer l’historique': 'مسح السجل',
      'Effacer l’historique ?': 'هل تريد مسح السجل؟',
      'Cette action est irréversible.': 'هذا الإجراء لا يمكن التراجع عنه.',
      'Annuler': 'إلغاء',
      'Effacer': 'مسح',
      'Tous': 'الكل',
      'Manqués': 'فائتة',
      'Entrants': 'واردة',
      'Sortants': 'صادرة',
      'Supprimer': 'حذف',
      'Aucun appel pour le moment.': 'لا توجد مكالمات حتى الآن.',
      'Les appels récents apparaîtront ici.': 'ستظهر المكالمات الحديثة هنا.',

      // ChatRoomAppBar / presence
      'Vu à l’instant': 'شوهد للتو',
      'Vu il y a': 'شوهد منذ',
      'min': 'د',
      'h': 'س',
      'Vu le': 'شوهد في',
      'Hors ligne': 'غير متصل',
      'En ligne': 'متصل',
      'en ligne': 'متصل',

      // NavigationScreen labels
      
      // SettingsScreen
      'Statut: En ligne': 'الحالة: متصل',
      'Statut: Hors ligne': 'الحالة: غير متصل',
      'Vos contacts vous voient “en ligne”.': 'يمكن لجهات اتصالك رؤيتك “متصلاً”.',
      'Vous apparaissez hors ligne (mode invisible).': 'تظهر كغير متصل (وضع التخفي).',
      'Visible': 'مرئي',
      'Invisible': 'مخفي',
      'Mon QR': 'رمزي QR',
      'Affiche ton code QR (valide ~30 jours) pour être ajouté rapidement.':
          'اعرض رمز QR الخاص بك (صالح ~30 يومًا) ليتم إضافتك بسرعة.',
      'Ouvrir': 'فتح',
      'Connexion Web': 'الاتصال عبر الويب',
      'Scanner le QR affiché sur le site pour ouvrir ta session.':
          'امسح رمز QR الظاهر على الموقع لفتح جلستك.',
      'Scanner': 'مسح',
       
'Sans expiration': 'بدون انتهاء',
'Expiré • Régénérer': 'انتهى • إعادة توليد',
'Expire dans': 'ينتهي خلال',
'j': 'ي',

'm': 'د',
'Régénérer': 'إعادة توليد',
'Aucun QR': 'لا يوجد رمز QR',

'Scanner — Connexion Web': 'مسح — اتصال الويب',
'Vous devez être connecté dans l’app.': 'يجب أن تكون مسجلاً دخولك في التطبيق.',
'Connecté': 'تم الاتصال',
'Retourne sur le Web — tu es connecté 👍': 'ارجع إلى الويب — تم الاتصال 👍',
'Échec': 'فشل',
'QR scanné.\nVérifie le navigateur Web.': 'تم مسح رمز QR.\nتحقق من المتصفح.',
'Terminer': 'إنهاء',


'Ajouter via QR': 'إضافة عبر QR',
'Échec QR': 'فشل QR',
'inconnu': 'غير معروف',
'QR invalide': 'رمز QR غير صالح',
'contactId manquant': 'معرّف جهة الاتصال مفقود',
'Utilisateur trouvé, mais son numéro n\'a pas été récupéré.\nAjoute-le manuellement ou complète le numéro.':
  'تم العثور على المستخدم لكن لم يتم جلب الرقم.\nأضفه يدويًا أو أكمل الرقم.',
'Contact ajouté': 'تمت إضافة جهة الاتصال',

'Succès, invitation envoyée à': 'تمت دعوة',
'Erreur, échec de l\'envoi de l\'invitation à': 'خطأ، فشل إرسال الدعوة إلى',
'Échec de la sélection de l\'image': 'فشل اختيار الصورة',
'Échec de l\'envoi de l\'invitation': 'فشل إرسال الدعوة',
'Nom du groupe': 'اسم المجموعة',
'Veuillez entrer un nom de groupe': 'يرجى إدخال اسم المجموعة',
'Créer': 'إنشاء',
'N/A': 'غير متاح',

'Contacts non enregistrés': 'جهات اتصال غير محفوظة',

'try_different_keywords': 'جرّب كلمات مفتاحية مختلفة',
  'swipe_to_decline': 'اسحب للرفض',
  'swipe_to_answer': 'اسحب للرد',
'scan_qr': 'مسح QR',
  'my_qr': 'رمزي QR',
  'connection_issue': 'مشكلة في الاتصال',
  'check_connection': 'تحقق من اتصالك بالإنترنت أو أعد المحاولة لاحقًا.',
  'rooms': 'الغُرَف',
  
  'room_id_optional': 'معرّف الغرفة (اختياري)',
  'join_create': 'انضم / أنشئ',
  'instructions': 'التعليمات',
  'swipe_up': 'اسحب للأعلى',
  'quick_guide': 'دليل سريع',
  'bullet_name': 'اكتب اسمك — سيظهر داخل الغرفة.',
  'bullet_join': 'للإنضمام: ألصِق معرّف غرفة وصلك.',
  'bullet_create': 'للإنشاء: اتركه فارغًا ثم اضغط « انضم / أنشئ ».',
  'bullet_share': 'شارك المعرّف بعد الدخول لدعوة الآخرين.',
  'tip_more': 'نصيحة: ابقِ هذه الورقة مرفوعة للأعلى لمزيد من المعلومات ✨',

   'Secure Encryption': 'تشفير آمن',
          'All your data is end-to-end encrypted':
              'جميع بياناتك مشفّرة من طرف إلى طرف',
          'Cloud Sync': 'مزامنة سحابية',
          'Access your data from any device':
              'يمكنك الوصول إلى بياناتك من أي جهاز',
          'Lightning Fast': 'سريع جدًا',
          'Optimized for maximum performance':
              'محسّن لأقصى أداء',


        },
        'en_US': {
           // ======= Onboarding Lang =======
          'choose_language': 'Choose your language',
          'change_anytime_hint': 'You can change it anytime in Settings → Language at the bottom.',
          'app_language': 'App language',
          'tip_change_later': 'Tip: You can also change language later in Settings.',
          'continue_btn': 'Continue',
          'lang_english': 'English',
          'lang_french': 'Français',
          'lang_arabic': 'العربية',
          'check_connection': 'Check your internet connection or try again later.',
          'retry': 'Retry',
          'connection_issue': 'Connection issue',
          'add': 'ADD',
           "clear_conversation": "Clear conversation",
  "clear_conversation_confirmation": "Are you sure you want to delete the entire conversation?",
  "clear": "Clear",
  
  "conversation_cleared": "Conversation cleared!",
  "conversation_empty": "Start a new conversation",
          'chat_bot_clear': 'Clear Chat',
          'chat_bot_close': 'Close',
          'welcome_message': 'Connecting you to the world with ease and style.',
          'feature_secure_title': 'Secure Conversations',
          'feature_secure_description':
              'Your privacy is our priority. All messages are end-to-end encrypted.',
          'feature_support_title': 'Cross-Platform Support',
          'feature_support_description':
              'Seamlessly stay connected across all your devices.',
          'feature_connected_title': 'Stay Connected',
          'feature_connected_description':
              'Chat with your loved ones or collaborate with your team.',
          'agree_and_continue': 'AGREE AND CONTINUE',
          'footer_powered_by': 'Powered by Bacallio Technologies',
          'verify_phone': 'Verify Your Phone',
          'verification_message':
              'Bacalio will send an SMS message to verify your phone number. Carrier charges may apply.',
          'your_phone_number': 'Your Phone Number',
          'phone_number_hint': 'Phone Number',
          'next': 'NEXT',
          'invalid_phone_number':
              'Enter a valid phone number (at least 6 digits).',
          'otp_verification': 'OTP Verification',
          'enter_otp_message': 'Enter the 6-digit code sent to your phone.',
          'clear_code': 'Clear Code',
          'verify': 'Verify',
          'invalid_otp_message': 'Error, Enter a valid 6-digit OTP code.',
          'otp_verified_message': 'Success, OTP Verified!',
          'invalid_otp_retry': 'Error, Invalid OTP. Try again.',
          'create_profile': 'Create Your Profile',
          'enter_name': 'Please enter your name.',
          'enter_your_name': 'Enter Your Name',
          'your_name': 'Your Name',
          'chats': 'Chats',
          'calls': 'Calls',
          'search_chats': 'Search Chats',
          'settings': 'Settings',
          'phone_number': 'Phone Number',
          'theme': 'Theme',
          'dark_mode': 'Dark Mode',
          'language': 'Language',
          'success': 'Success',
          'error': 'Error',
          'no_results_found': 'No Results Found',
          'no_contacts_match': 'No contacts match your search.',
          'no_chats_yet': 'No chats yet',
          'type_a_message': 'Type a message...',
          'online': 'Online',
          'Chats': 'Chats',
          'Calls': 'Calls',
          'Settings': 'Settings',
          'New Group': 'New Group',
          'Notice': 'Notice',
          'All Contacts': 'All Contacts',
          'Search for a contact or select one from the list below.':
              'Search for a contact or select one from the list below.',
          'Search Contacts': 'Search Contacts',
          'No contacts match your search.': 'No contacts match your search.',
          'Unknown': 'Unknown',
          'No Phone Number': 'No Phone Number',
          'Create Group Chat': 'Create Group Chat',
          'Select contacts to create a group chat.':
              'Select contacts to create a group chat.',
          'Create Group': 'Create Group',
          'Profile': 'Profile',
          'Call': 'Call',
          'Video Call': 'Video Call',
          'Message': 'Message',
          'Add Contact': 'Add Contact',
          'Phone Number': 'Phone Number',
          'About': 'About',
          'Joined in January 2023': 'Joined in January 2023',
          'An error occurred.': 'An error occurred.',
          'No recent calls': 'No recent calls',
          'Recent': 'Recent',
          "Welcome Back!": "Welcome Back!",
          "Login to your account": "Login to your account",
          "Email": "Email",
          "Enter your email": "Enter your email",
          "Password": "Password",
          "Enter your password": "Enter your password",
          "Forgot Password?": "Forgot Password?",
          "Login": "Login",
          "Don't have an account?": "Don't have an account?",
          "Sign Up": "Sign Up",
          "Error,Please fill in all fields.":
              "Error,Please fill in all fields.",
          "Create Profile": "Create Profile",
          "Fill in the details below to create your profile.":
              "Fill in the details below to create your profile.",
          "Name": "Name",
          "Enter your name": "Enter your name",
          "By creating a profile, you agree to our Terms & Conditions.":
              "By creating a profile, you agree to our Terms & Conditions.",
          "Please fill all fields": "Please fill all fields",
          "failed_to_retrieve_token":
              "Failed to retrieve token. Please log in again.",
          "failed_to_retrieve_token_2": "Failed to retrieve token.",
          "sending_status": "Sending Status",
          "recording": "Recording...",
          "attach_image": "Attach Image",
          "attach_video": "Attach Video",
          "record_voice_message": "Record Voice Message",
          "allow_notifications": "Allow notifications",
          "allow_contacts": "Allow Contacts",
          "group_details": "Group Details",
          "group_name": "Group Name",
          "tap_to_upload_logo": "Tap to upload logo",
          "cancel": "Cancel",
          "create": "Create",
          "error_failed_to_create_group": "Failed to create group",
          "add_contact": "Add Contact",
          "search_by_phone_number": "Search by Phone Number",
          "search_for_a_user_and_add_them_to_your_contacts":
              "Search for a user and add them to your contacts.",
          "enter_phone_number_in_the_search_bar_above":
              "Enter phone number in the search bar above.",
          "no_users_found": "No users found.",
          "please_try_another_search_term": "Please try another search term.",
          "error_failed_to_add_contact": "Error, Failed to add contact",
          "success_contact_added":
              "Success, the contact has been added to your contacts.",
          "Logout": "Logout",
          "Update Profile": "Update Profile",
          "Update your profile details below.":
              "Update your profile details below.",
          "Tell us about yourself": "Tell us about yourself",
          "Changes will be reflected immediately.":
              "Changes will be reflected immediately.",
          'enter_phone_number': 'Enter Phone Number',
          'phone_number_description':
              'Please enter the phone number of the contact you want to add. If the phone number is already registered, the name field will be automatically filled.',
          'enter_phone_hint': 'Enter your phone number',
          'name_description':
              'Please enter the name of the contact. If the phone number is already registered, the name field will be pre-filled and disabled.',
          'name': 'Name',
          'enter_name_hint': 'Enter your name',
          'back': 'Back',
          'save': 'Save',
          'token_error': 'Failed to retrieve token. Please log in again.',
          'phone_check_error': 'Failed to check phone number: ',
          'empty_phone_error': 'Please enter a phone number.',
          'empty_name_error': 'Please enter a name.',
          'contact_already_added': 'Contact already added',
          'contact_added_success': 'Contact added successfully!',
          'contact_added_to_phone': 'Contact added to phone!',
          'contact_add_error': 'Failed to add contact: ',
          'step_1': 'Step 1',
          'step_2': 'Step 2',
          'hi_how_can_i_assist_you?': 'Hi! How can I assist you?',
          'forgot_password': 'Forgot Password',
          "failed_to_send_OTP_Please_try_again.":
              "Failed to send OTP. Please try again.",
          "OTP_verified_successfully!": "OTP verified successfully!",
          "invalid_OTP_please_try_again.": "Invalid OTP. Please try again.",
          "invalid_OTP": "Invalid OTP",
          'new_password': 'New Password',
          'confirm_password': 'Confirm Password',
          'enter_new_password': 'Enter New Password',
          "Re-enter_your_new_password": "Re-enter your new password",
          "please_fill_all_fields": "Please fill all fields",
          "Password_must_be_at_least_8_characters_long_and_contain_uppercase_lowercase_letters_and_numbers":
              "Password must be at least 8 characters long and contain uppercase, lowercase letters and numbers",
          "passwords_do_not_match": "Passwords do not match",
          "password_updated_successfully": "Password updated successfully",
          "error_failed_to_update_password": "Failed to update password",
          "failed_to_send_OTP._please_try_again.":
              "Failed to send OTP. Please try again.",
          'Are you sure you want to log out?':
              'Are you sure you want to log out?',
          'Yes': 'Yes',
          'No': 'No',
          "call_failed": "Call Failed",
          'une_erreur_inattendue_s_est_produite._veuillez_réessayer.':
              'An unexpected error occurred. Please try again.',
          "The user has not installed the app ":
              "The user has not installed the app.",
          "No user has been selected for the call. Please check the invitees list.":
              "No user has been selected for the call. Please check the invitees list.",
          'Un appel est déjà en cours. Veuillez réessayer plus tard.':
              "call already in progress. Please try again later.",
          "Please check your credentials": "Please check your credentials",
          'Failed to log out. Please try again.':
              'Failed to log out. Please try again.',
          "User already exist": "User already exist",
          'Failed to update profile. Please try again.':
              'Failed to update profile. Please try again.',
          'Failed to fetch messages. Please try again.':
              'Failed to fetch messages. Please try again.',
          "Failed to get AI response": "Failed to get AI response:",
          'remember_me': 'Remember Me',
          "texte_copié": "Text copied",
          "image_was_sent": "Image was sent",
          "video_message_was_sent": "Video message was sent",
          "audio_message_was_sent": "Audio message was sent",
          "please_provide_a_group_name.": "Please provide a group name.",
          "this_contact_n'est_pas_encore_sur_B-callio.Invitez-le_à_nous_rejoindre !":
              "This contact is not yet on B-callio. Invite them to join us!",
          "inviter_par_sms": "Invite by SMS",
          "pas_maintenant": "Not now",
          "anglais": "English",
          "français": "French",
          "arabic": "Arabic",
          "no_messages_yet": "No messages yet",
          "un_de_vos_contacts_n_a_pas_encore_utilisé_application.":
              "One of your contacts has not yet used the app.",
          "success_invitation_sent_to_contact":
              "Success, Invitation sent to contact",
          "error_failed_to_send_invitation_to_contact":
              "Error! Failed to send invitation to contact.",
          "No Name Available": "No Name Available",
          "search_country": "Search Country",
          "camera": "Camera",
          "gallery": "Gallery",
          "permission_requise": "Permission required",
          "Vous devez autoriser l'accès à la galerie dans les paramètres.":
              "You need to allow access to the gallery in settings.",
          "Vous devez autoriser l'accès à la caméra dans les paramètres.":
              "You need to allow access to the camera in settings.",
          "Vous devez autoriser l'accès au microphone dans les paramètres.":
              "You need to allow access to the microphone in settings.",
          "Ouvrir les paramètres": "Open settings",
          "A screenshot has been taken!": "A screenshot has been taken!",
          "Location": "Location",
          "Chat": "Chat",
          "Contact": "Contact",
          "has entered the chat!": "has entered the chat!",
          'Tap a marker to show route, double-tap for details':
              'Tap a marker to show route, double-tap for details',
          "Delete Conversation": "Delete Conversation",
          "Are you sure you want to delete this conversation?":
              "Are you sure you want to delete this conversation?",
          "Delete": "Delete",
          'Copied': 'Copied',
          'Message copied to clipboard': 'Message copied to clipboard',
          'Copy': 'Copy',
          'Delete Message': 'Delete Message',
          "Are you sure you want to delete this message?":
              "Are you sure you want to delete this message?",
          'user_entered': '[system] :name has entered the chat!',

          // Calls / toasts / statuses
      'a rejoint l’appel': 'joined the call',
      'Ne répond pas': 'No answer',
      'Occupé': 'Busy',
      'Appel terminé': 'Call ended',
      'Waiting for participants…': 'Waiting for participants…',
      'Me': 'Me',
      'Calling…': 'Calling…',
      'In group call…': 'In group call…',
      'In call…': 'In call…',
      'Group video call': 'Group video call',
      'Group audio call': 'Group audio call',
      'Video call': 'Video call',
      'Audio call': 'Audio call',

      // Chatbot modal
      'BCalio-AI': 'BCalio-AI',
      'Hi! I\'m your AI assistant': 'Hi! I\'m your AI assistant',
      'Ask me anything, and I\'ll help you find answers':
          'Ask me anything, and I\'ll help you find answers',
      
      // Clear dialog
      
      
       // CallLogScreen
      'Journal d’appel': 'Call log',
      'Effacer l’historique': 'Clear history',
      'Effacer l’historique ?': 'Clear history?',
      'Cette action est irréversible.': 'This action is irreversible.',
      'Annuler': 'Cancel',
      'Effacer': 'Clear',
      'Tous': 'All',
      'Manqués': 'Missed',
      'Entrants': 'Incoming',
      'Sortants': 'Outgoing',
      'Supprimer': 'Delete',
      'Aucun appel pour le moment.': 'No calls yet.',
      'Les appels récents apparaîtront ici.': 'Recent calls will appear here.',

      // ChatRoomAppBar / presence
      'Vu à l’instant': 'Seen just now',
      'Vu il y a': 'Seen',
      'min': 'min',
      'h': 'h',
      'Vu le': 'Seen on',
      'Hors ligne': 'Offline',
      'En ligne': 'Online',
      'en ligne': 'online',

      // NavigationScreen labels
      

      // SettingsScreen
      'Statut: En ligne': 'Status: Online',
      'Statut: Hors ligne': 'Status: Offline',
      'Vos contacts vous voient “en ligne”.': 'Your contacts can see you “online”.',
      'Vous apparaissez hors ligne (mode invisible).': 'You appear offline (invisible mode).',
      'Visible': 'Visible',
      'Invisible': 'Invisible',
      'Mon QR': 'My QR',
      'Affiche ton code QR (valide ~30 jours) pour être ajouté rapidement.':
          'Show your QR code (valid ~30 days) to be added quickly.',
      'Ouvrir': 'Open',
      'Connexion Web': 'Web login',
      'Scanner le QR affiché sur le site pour ouvrir ta session.':
          'Scan the QR shown on the website to open your session.',
      'Scanner': 'Scan',
      
'Sans expiration': 'No expiration',
'Expiré • Régénérer': 'Expired • Regenerate',
'Expire dans': 'Expires in',
'j': 'd',

'm': 'm',
'Régénérer': 'Regenerate',
'Aucun QR': 'No QR',

'Scanner — Connexion Web': 'Scan — Web login',
'Vous devez être connecté dans l’app.': 'You must be logged in to the app.',
'Connecté': 'Connected',
'Retourne sur le Web — tu es connecté 👍': 'Go back to the web — you are connected 👍',
'Échec': 'Failed',
'QR scanné.\nVérifie le navigateur Web.': 'QR scanned.\nCheck your web browser.',
'Terminer': 'Finish',


'Ajouter via QR': 'Add via QR',
'Échec QR': 'QR failure',
'inconnu': 'unknown',
'QR invalide': 'Invalid QR',
'contactId manquant': 'missing contactId',
'Utilisateur trouvé, mais son numéro n\'a pas été récupéré.\nAjoute-le manuellement ou complète le numéro.':
  'User found, but phone number was not retrieved.\nAdd manually or complete the number.',
'Contact ajouté': 'Contact added',

'Succès, invitation envoyée à': 'Success, invitation sent to',
'Erreur, échec de l\'envoi de l\'invitation à': 'Error, failed to send invitation to',
'Échec de la sélection de l\'image': 'Failed to pick image',
'Échec de l\'envoi de l\'invitation': 'Failed to send invitation',
'Nom du groupe': 'Group name',
'Veuillez entrer un nom de groupe': 'Please enter a group name',
'Créer': 'Create',
'N/A': 'N/A',

'Contacts enregistrés': 'Saved contacts',
'Contacts non enregistrés': 'Unsaved contacts',
'try_different_keywords': 'Try different keywords',
  'swipe_to_decline': 'Swipe to decline',
  'swipe_to_answer': 'Swipe to answer',
'scan_qr': 'Scan QR',
  'my_qr': 'My QR',

  'rooms': 'Rooms',
  
  'room_id_optional': 'Room ID (optional)',
  'join_create': 'Join / Create',
  'instructions': 'Instructions',
  'swipe_up': 'Swipe up',
  'quick_guide': 'Quick guide',
  'bullet_name': 'Enter your name — it appears in the room.',
  'bullet_join': 'To join: paste a Room ID you received.',
  'bullet_create': 'To create: leave it empty, then “Join / Create”.',
  'bullet_share': 'Share the ID after entering to invite someone.',
  'tip_more': 'Tip: keep this sheet pulled up to see more ✨',

  
  'Room': 'Room',

  'Secure Encryption': 'Secure Encryption',
          'All your data is end-to-end encrypted':
              'All your data is end-to-end encrypted',
          'Cloud Sync': 'Cloud Sync',
          'Access your data from any device':
              'Access your data from any device',
          'Lightning Fast': 'Lightning Fast',
          'Optimized for maximum performance':
              'Optimized for maximum performance',
  

        },
      };
}
