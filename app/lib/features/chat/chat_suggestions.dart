// Three suggested questions per title kind (CONTRACTS 4.2 allows templates
// built on the device). Written by hand, no AI call. Worded without
// pronouns so one list fits every leader and thinker.

/// The questions shown while a chat is empty. [kind] is the catalogue
/// `kind`: `topic`, `leader` or `thinker`.
List<String> chatSuggestions({required String kind, required String name}) =>
    switch (kind) {
      'leader' => [
        'What is $name known for?',
        'What odds did $name beat?',
        'What can I learn from $name?',
      ],
      'thinker' => [
        'What is $name known for?',
        'What were the big ideas?',
        'How can I use these ideas today?',
      ],
      _ => [
        'Give me a short summary',
        'Who were the key people?',
        'Why does it still matter today?',
      ],
    };
