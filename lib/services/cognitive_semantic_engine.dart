/// Cognitive Semantic Engine
/// Implements Spreading Activation Theory (Collins & Loftus) and
/// Concept Taxonomy Mapping to model how human memory associates ideas.
class CognitiveDomain {
  final String id;
  final String name;
  final Set<String> queryTriggers;
  final Set<String> associatedSkills;
  final Set<String> associatedRoles;
  final String explanationTemplate;

  const CognitiveDomain({
    required this.id,
    required this.name,
    required this.queryTriggers,
    required this.associatedSkills,
    required this.associatedRoles,
    required this.explanationTemplate,
  });
}

class SemanticMatchExplanation {
  final String queryConcept;
  final String domainName;
  final List<String> activatedSkills;
  final String reasoningSentence;

  const SemanticMatchExplanation({
    required this.queryConcept,
    required this.domainName,
    required this.activatedSkills,
    required this.reasoningSentence,
  });
}

class CognitiveSemanticEngine {
  /// Curated cognitive ontology domains modeling software, design, and human collaboration
  static final List<CognitiveDomain> _domains = [
    // 1. Mobile Application Ecosystem
    const CognitiveDomain(
      id: 'mobile_app',
      name: 'Mobile App Ecosystem',
      queryTriggers: {
        'mobile', 'app', 'apps', 'application', 'applications', 'phone', 'smartphone',
        'android', 'ios', 'swift', 'kotlin', 'flutter', 'dart', 'react native',
        'mobile app', 'app developer', 'android developer', 'ios developer',
        'mobile developer', 'mobile engineer', 'mobile architect', 'cross platform',
        'cross-platform', 'client', 'frontend mobile', 'apk', 'play store', 'app store',
        // Broader developer intent synonyms
        'native', 'native app', 'native android', 'native mobile',
        'app builder', 'app creator', 'build apps', 'builds apps',
        'android app', 'flutter app', 'ios app', 'mobile product',
        'build mobile', 'ship mobile', 'mobile side project',
      },
      associatedSkills: {
        'flutter', 'android', 'dart', 'kotlin', 'ios', 'swift', 'react native',
        'mobile ux', 'cross-platform', 'mobile expert', 'side projects',
      },
      associatedRoles: {
        'mobile architect', 'android developer', 'flutter developer',
        'mobile engineer', 'full-stack architect', 'side project developer',
        // Architect is a senior developer — bridge it
        'architect', 'full-stack', 'senior mobile',
      },
      explanationTemplate: 'relates to Android & Flutter mobile app architectures',
    ),

    // 2. Artificial Intelligence & Machine Learning
    const CognitiveDomain(
      id: 'ai_ml',
      name: 'AI & Machine Learning',
      queryTriggers: {
        'ai', 'ml', 'artificial intelligence', 'machine learning', 'deep learning',
        'neural', 'neural network', 'llm', 'llms', 'language model', 'large language model',
        'transformer', 'gpt', 'chatgpt', 'agent', 'agents', 'ai agent', 'ai agents',
        'on-device ai', 'on device ai', 'local ai', 'coreml', 'quantization', 'pytorch',
        'tensorflow', 'python', 'hugging face', 'edge ai', 'computer vision', 'nlp',
        'model', 'models', 'inference', 'weights', 'ai researcher', 'ml engineer',
      },
      associatedSkills: {
        'pytorch', 'on-device ai', 'c++', 'python', 'coreml', 'machine learning',
        'ai agents', 'quantization',
      },
      associatedRoles: {
        'machine learning engineer', 'staff machine learning engineer',
        'ai researcher', 'quantization researcher', 'ai engineer',
      },
      explanationTemplate: 'activates On-device AI, PyTorch & Quantization research',
    ),

    // 3. Distributed Systems & Cloud Infrastructure
    const CognitiveDomain(
      id: 'cloud_infra',
      name: 'Cloud & Distributed Infrastructure',
      queryTriggers: {
        'cloud', 'backend', 'infra', 'infrastructure', 'distributed systems', 'distributed',
        'systems', 'server', 'servers', 'serverless', 'scalability', 'scale', 'high throughput',
        'edge', 'edge computing', 'edge workers', 'cloudflare', 'cloudflare workers',
        'go', 'golang', 'rust', 'docker', 'kubernetes', 'k8s', 'devops', 'database',
        'databases', 'sql', 'postgresql', 'postgres', 'd1', 'caching', 'cto', 'architect',
      },
      associatedSkills: {
        'go', 'cloudflare workers', 'rust', 'postgresql', 'docker', 'cloudflare',
        'backend', 'devops', 'distributed systems',
      },
      associatedRoles: {
        'distributed systems lead', 'infrastructure wizard', 'system architect',
        'backend engineer', 'cloud engineer', 'potential cto',
      },
      explanationTemplate: 'connects to Cloudflare Workers, Go & Rust distributed systems',
    ),

    // 4. Product Design, UI & UX
    const CognitiveDomain(
      id: 'design_ux',
      name: 'Product Design & User Experience',
      queryTriggers: {
        'design', 'designer', 'ui', 'ux', 'ui/ux', 'product design', 'creative',
        'visual', 'look', 'aesthetic', 'interface', 'user interface', 'user experience',
        'figma', 'design system', 'design systems', 'prototyping', 'prototype',
        'micro-interactions', 'typography', 'haptics', 'tailwind', 'styling', 'craft',
      },
      associatedSkills: {
        'figma', 'design systems', 'mobile ux', 'tailwind', 'prototyping', 'design',
        'ui/ux', 'mobile systems',
      },
      associatedRoles: {
        'lead ui/ux designer', 'designer', 'design maestro', 'aesthetic visionary',
        'product designer',
      },
      explanationTemplate: 'maps to Figma, Mobile UX & Accessible Design Systems',
    ),

    // 5. Entrepreneurship, Startups & Leadership
    const CognitiveDomain(
      id: 'founders',
      name: 'Founders & Startup Leadership',
      queryTriggers: {
        'founder', 'founders', 'co-founder', 'cofounder', 'startup', 'startups',
        'entrepreneur', 'building a startup', 'partner', 'partnering', 'side project',
        'side projects', 'indie builder', 'indie hacker', 'creator', 'team up', 'collaborate',
        'collaboration', 'potential cto', 'lead', 'leadership', 'aspirational',
      },
      associatedSkills: {
        'side projects', 'ai agents', 'flutter', 'cloudflare', 'mobile expert',
      },
      associatedRoles: {
        'founder', 'architect', 'lead', 'indie builder', 'co-founder',
      },
      explanationTemplate: 'associates with Aspirational Founder & Startup Collaboration',
    ),

    // 6. Episodic & Sensory Recall Triggers
    const CognitiveDomain(
      id: 'sensory_episodic',
      name: 'Episodic Sensory Anchor',
      queryTriggers: {
        'matcha', 'coffee', 'espresso', 'tea', 'drink', 'drinks', 'beer', 'dinner',
        'lunch', 'hallway', 'talk', 'tech talk', 'cam', "cam's", 'summit', 'expo',
        'conference', 'demo', 'napkin', 'backpack', 'shoes', 'accent', 'sketchbook',
      },
      associatedSkills: {},
      associatedRoles: {},
      explanationTemplate: 'retrieves episodic sensory anchor from where & how you met',
    ),
  ];


  /// Evaluates query against the cognitive ontology, returning activated domains
  /// and concept bridges.
  static List<SemanticMatchExplanation> analyzeQuery(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return [];

    final explanations = <SemanticMatchExplanation>[];

    for (final domain in _domains) {
      // Check if full query or any n-gram trigger is present
      String? matchedTrigger;
      for (final trigger in domain.queryTriggers) {
        if (q.contains(trigger) || trigger.contains(q)) {
          matchedTrigger = trigger;
          break;
        }
      }

      if (matchedTrigger != null) {
        explanations.add(SemanticMatchExplanation(
          queryConcept: matchedTrigger,
          domainName: domain.name,
          activatedSkills: domain.associatedSkills.toList(),
          reasoningSentence: domain.explanationTemplate,
        ));
      }
    }

    return explanations;
  }

  /// Calculates semantic spreading activation score between query and a contact's profile
  static Map<String, dynamic> computeActivation({
    required String query,
    required List<String> contactSkills,
    required String contactRole,
    required String contactHeadline,
    required List<String> contactVibes,
    required String distinctiveMemory,
    required String microContext,
    required List<String> callWhen,
    required String futureSelfNote,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return {'score': 0.0, 'reason': '', 'concept': ''};
    }

    final queryAnalysis = analyzeQuery(q);
    double totalActivation = 0.0;
    String topReason = '';
    String topConcept = '';

    final lowerSkills = contactSkills.map((s) => s.toLowerCase()).toSet();
    final lowerRole = contactRole.toLowerCase();
    final lowerHeadline = contactHeadline.toLowerCase();
    final lowerVibes = contactVibes.map((v) => v.toLowerCase()).toSet();
    final lowerMemory = distinctiveMemory.toLowerCase();
    final lowerContext = microContext.toLowerCase();
    final lowerCallWhen = callWhen.map((c) => c.toLowerCase()).toSet();
    final lowerFutureSelf = futureSelfNote.toLowerCase();

    // Check direct episodic memory anchors (Highest human signal!)
    if (lowerMemory.isNotEmpty && (q.contains(lowerMemory) || lowerMemory.contains(q))) {
      totalActivation += 70.0;
      topReason = 'Episodic Anchor: "$distinctiveMemory"';
      topConcept = 'Distinctive Memory';
    }
    if (lowerContext.isNotEmpty && (q.contains(lowerContext) || lowerContext.contains(q))) {
      totalActivation += 55.0;
      topReason = 'Scene Anchor: "$microContext"';
      topConcept = 'Micro-Context';
    }
    for (final trigger in lowerCallWhen) {
      if (q.contains(trigger) || trigger.contains(q)) {
        totalActivation += 65.0;
        topReason = 'Recall Trigger: "Call when $trigger"';
        topConcept = 'Future Action Anchor';
      }
    }

    // Check cognitive domains spreading activation
    for (final exp in queryAnalysis) {
      final domain = _domains.firstWhere((d) => d.name == exp.domainName);

      // Check if contact has any of this domain's skills
      final sharedSkills = lowerSkills.intersection(domain.associatedSkills);
      if (sharedSkills.isNotEmpty) {
        final weight = 45.0 + (sharedSkills.length * 10.0);
        totalActivation += weight;
        if (topReason.isEmpty) {
          topConcept = domain.name;
          final skillNames = contactSkills.where((s) => domain.associatedSkills.contains(s.toLowerCase())).take(2).join(' & ');
          topReason = 'Concept link: "${exp.queryConcept}" ➔ $skillNames (${exp.reasoningSentence})';
        }
      }

      // Check if contact's role matches domain roles
      for (final r in domain.associatedRoles) {
        if (lowerRole.contains(r) || lowerHeadline.contains(r)) {
          totalActivation += 40.0;
          if (topReason.isEmpty) {
            topConcept = domain.name;
            topReason = 'Role association: "${exp.queryConcept}" relates to $contactRole';
          }
        }
      }
    }

    // ─── Role Synonym Bridge ───────────────────────────────────────────────
    // "developer" / "engineer" / "architect" / "lead" / "specialist" are
    // different title words for the same idea — a practitioner in that domain.
    // If the user searches for "developer" but the contact is an "architect",
    // we still give a significant bonus so they surface.
    const roleSynonyms = {
      'developer', 'engineer', 'architect', 'lead', 'specialist',
      'builder', 'creator', 'maker', 'practitioner', 'expert',
    };
    final queryHasRoleSynonym = roleSynonyms.any((s) => q.contains(s));
    final contactHasRoleSynonym = roleSynonyms.any((s) =>
        lowerRole.contains(s) || lowerHeadline.contains(s));

    if (queryHasRoleSynonym && contactHasRoleSynonym && totalActivation > 0) {
      // Both query and contact use role-tier words → boost bridging score
      totalActivation += 30.0;
      if (topReason.isEmpty) {
        topReason = 'Role synonym bridge: "${q.split(' ').where(roleSynonyms.contains).join(', ')}" → $contactRole';
      }
    }

    // ─── Token-Level Skill Matching for Multi-Word Queries ─────────────────
    // Break query into individual tokens and match each against contact skills.
    // This catches "android developer" finding contacts with skill "Android"
    // even if the contact's role is "Architect" (not "Developer").
    final queryTokens = q
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 2)
        .toSet();

    for (final token in queryTokens) {
      for (final skill in lowerSkills) {
        if (skill.contains(token) || token.contains(skill)) {
          if (totalActivation == 0 || topReason.isEmpty) {
            // Provide a reason even when only a token matched a skill
            final originalSkill = contactSkills.firstWhere(
              (s) => s.toLowerCase() == skill,
              orElse: () => skill,
            );
            totalActivation += 35.0;
            topReason = 'Skill token match: "$token" activates skill "$originalSkill"';
            topConcept = 'Direct Skill';
          } else {
            totalActivation += 15.0;
          }
          break;
        }
      }
    }

    return {
      'score': totalActivation,
      'reason': topReason,
      'concept': topConcept,
    };
  }
}
