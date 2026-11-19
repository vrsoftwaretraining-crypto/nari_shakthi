// Developed by Codesoftwares
// Text shown on the website. The quotes are original lines.
// The stories below are ILLUSTRATIVE (they are labelled that way on screen).
// Before launch, replace them with real stories from members who gave written permission.

const successQuotes = <String>[
  'A second chapter can be the one you were always meant to write.',
  'Starting again is not starting over. It is starting with strength.',
  'Healing made room, and love walked in.',
  'Your past shaped you. It does not decide your happiness.',
  'Two people who know what matters can build a home that lasts.',
  'Real love is patient, kind, and often arrives when you are ready for it.',
  'A happy second marriage begins with respect, honesty and a lot of laughter.',
  'What you learned yesterday makes the love you build tomorrow stronger.',
];

class Story {
  final String title, text, image;
  const Story(this.title, this.text, this.image);
}

const successStories = <Story>[
  Story('A new beginning at 38',
      'After years of raising her daughter alone, she wanted a partner who respected her family first. They shared values, talked for weeks, and now the three of them have dinner together every Sunday.',
      'assets/web/story1.jpg'),
  Story('Two families, one home',
      'A widower with two sons and a divorced teacher introduced the children slowly and kept every promise. Trust grew one small step at a time.',
      'assets/web/story2.jpg'),
  Story('Second chances are quiet',
      'He thought companionship was behind him. A simple conversation about books became a friendship, and the friendship became a partnership built on honesty.',
      'assets/web/story3.jpg'),
  Story('Strength after loss',
      'Widowed young, she believed her happiest days were over. With patience and a family that supported her choice, she met a kind man who honours her past and shares her future.',
      'assets/web/story4.jpg'),
  Story('Peace after separation',
      'Both had been through a difficult separation. They agreed to move slowly, talked openly about their fears, and found calm and laughter in each other.',
      'assets/web/story5.jpg'),
  Story('A home full of music',
      'A single father and a divorced music teacher bonded over their love of old songs. Today their home is full of music, and their children play together.',
      'assets/web/story6.jpg'),
];
