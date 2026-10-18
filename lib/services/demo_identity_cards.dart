import '../models/contact_card.dart';
import '../models/card_link.dart';

List<ContactCard> demoIdentityCards() {
  const profiles = [
    [
      'integration',
      'Integration Lead',
      'Connecting systems, teams, and ideas.',
      'Leading API integration, reliable data flows, and connected business platforms.',
      'API Integration,System Integration,APIs,Delivery Leadership',
      '#2563EB',
    ],
    [
      'architecture',
      'Senior IT Architect',
      'Designing technology that grows with the business.',
      'Shaping scalable systems, cloud architecture, and practical technology roadmaps.',
      'Solution Architecture,Cloud Architecture,System Design,Technical Strategy',
      '#0D9488',
    ],
    [
      'create',
      'Create · Creative Technologist',
      'Turning ideas into stories and experiences.',
      'Exploring creative technology, visual storytelling, and content through AuruNex Ventures.',
      'Creative Technology,Content Creation,Storytelling,Design',
      '#7C3AED',
    ],
    [
      'build',
      'Build · Product & App Builder',
      'Building useful products from everyday problems.',
      'Creating mobile apps, web products, and AI-assisted experiences with a focus on usability.',
      'Flutter,Android,Web Development,AI,Product Development',
      '#D97706',
    ],
    [
      'explore',
      'Explore · Technology Explorer',
      'Curiosity, conversations, and new possibilities.',
      'Meeting makers, exploring emerging technology, and finding opportunities to collaborate.',
      'Emerging Technology,Experimentation,Community,Collaboration',
      '#DB2777',
    ],
  ];
  final date = DateTime.utc(2026, 10, 17);
  return List.generate(profiles.length, (i) {
    final p = profiles[i];
    return ContactCard(
      id: 'aurunex-persona-v1-${p[0]}',
      title: 'AuruNex Ventures',
      fullName: 'Anit Singh',
      company: 'AuruNex Ventures',
      category: i < 2 ? CardCategory.professional : CardCategory.custom,
      role: p[1],
      headline: p[2],
      bio: p[3],
      techStack: p[4].split(','),
      links: const [
        CardLink(
          id: 'aurunex-website',
          title: 'AuruNex Ventures',
          url: 'https://aurunex.com',
          type: LinkType.website,
        ),
      ],
      themeColorHex: p[5],
      createdAt: date,
      updatedAt: date,
    );
  });
}
