// ============================================================
// CHAT ICEBREAKERS
// Bengali + English conversation starters
// Categories: General, Family, Career, Fun, Deep
// ============================================================

class ChatIcebreakers {
  // ------------------------------------------------------------
  // BENGALI
  // ------------------------------------------------------------
  static const List<String> bangla = [
    // General
    'আপনার প্রিয় জেলা কোনটি?',
    'ছোটবেলা কোথায় বেড়াতে যেতেন?',
    'আপনার প্রিয় খাবার কী?',
    'ছুটির দিনে কী করতে ভালো লাগে?',
    'প্রিয় ঋতু কোনটি?',
    'সকালে উঠে প্রথম কী করেন?',
    'কফি না চা — কোনটা পছন্দ?',
    'বৃষ্টির দিনে কী করতে ভালো লাগে?',
    'পছন্দের ভ্রমণ স্পট কোনটি?',
    'সপ্তাহান্তে কী করেন?',

    // Family
    'পরিবারে কতজন সদস্য আছেন?',
    'পরিবারের সাথে সবচেয়ে মজার মুহূর্ত কোনটি?',
    'আপনার মা-বাবার সাথে কেমন সম্পর্ক?',
    'পরিবারে কার সাথে সবচেয়ে ঘনিষ্ঠ?',
    'ছোটবেলার কোনো মজার গল্প বলুন',

    // Career
    'আপনার পেশা সম্পর্কে একটু বলুন',
    'কেন এই পেশা বেছে নিলেন?',
    'কাজের সবচেয়ে প্রিয় অংশ কোনটি?',
    'চাকরি জীবনের সেরা অর্জন কী?',

    // Fun
    'কোন ধরনের গান শুনতে ভালো লাগে?',
    'বাংলা সিনেমার কোনটা প্রিয়?',
    'প্রিয় অভিনেতা কে?',
    'শখ কী?',
    'খেলাধুলা করতে ভালো লাগে?',

    // Deep
    'আপনার লাইফ গোল কী?',
    'আপনার আদর্শ জীবনসঙ্গী কেমন হবে?',
    'জীবনে সবচেয়ে বড় শিক্ষা কী?',
    '১০ বছর পর নিজেকে কোথায় দেখতে চান?',
    'কোন একটা কথা আপনার জীবন বদলে দিয়েছে?',
  ];

  // ------------------------------------------------------------
  // ENGLISH
  // ------------------------------------------------------------
  static const List<String> english = [
    // General
    'Which is your favorite district?',
    'Where did you travel as a kid?',
    'What\'s your favorite food?',
    'What do you like on holidays?',
    'Which is your favorite season?',
    'What\'s the first thing you do in morning?',
    'Coffee or tea?',
    'What do you like on a rainy day?',
    'Favorite travel destination?',
    'What do you do on weekends?',

    // Family
    'How many members in your family?',
    'What\'s your funniest family moment?',
    'How is your relationship with parents?',
    'Who are you closest to in family?',
    'Tell me a childhood story',

    // Career
    'Tell me about your profession',
    'Why did you choose this career?',
    'What\'s the best part of your job?',
    'Biggest achievement at work?',

    // Fun
    'What kind of music do you like?',
    'Which Bengali movie is your favorite?',
    'Who is your favorite actor?',
    'What are your hobbies?',
    'Do you like sports?',

    // Deep
    'What\'s your life goal?',
    'What kind of life partner do you want?',
    'Biggest lesson life taught you?',
    'Where do you see yourself in 10 years?',
    'What words changed your life?',
  ];

  // ------------------------------------------------------------
  // Get random icebreakers — optionally filtered
  // ------------------------------------------------------------
  static List<String> getRandom(bool isBangla, {int count = 4}) {
    final list = isBangla ? bangla : english;
    final shuffled = List<String>.from(list)..shuffle();
    return shuffled.take(count).toList();
  }
}
