num _jsonNumber(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

class AppBootstrap {
  const AppBootstrap({
    required this.appTitle,
    required this.supportedLocales,
    required this.featureFlags,
    required this.modules,
  });

  final String appTitle;
  final List<String> supportedLocales;
  final Map<String, bool> featureFlags;
  final List<String> modules;

  factory AppBootstrap.fromJson(Map<String, dynamic> json) {
    return AppBootstrap(
      appTitle: json['appTitle'] as String? ?? 'Christian Youth Super App',
      supportedLocales: (json['supportedLocales'] as List<dynamic>? ?? const [])
          .cast<String>(),
      featureFlags:
          (json['featureFlags'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, value == true),
      ),
      modules: (json['modules'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  static AppBootstrap fallback() {
    return const AppBootstrap(
      appTitle: 'Christian Youth Super App',
      supportedLocales: ['en', 'am'],
      featureFlags: {
        'bibleNotes': true,
        'courtship': true,
        'premium': false,
        'teenZone': true,
        'payments': true,
      },
      modules: [
        'auth',
        'users',
        'churches',
        'posts',
        'groups',
        'events',
        'chat',
        'moderation',
        'feed',
        'bible',
        'prayer',
        'growth',
        'ministries',
        'mentorship',
        'stories',
        'payments',
        'courtship',
        'opportunities',
        'media',
        'talent',
        'notifications',
        'search'
      ],
    );
  }
}

class ChurchItem {
  const ChurchItem({
    required this.id,
    required this.name,
    required this.city,
    required this.verified,
    this.description = '',
    this.logoUrl = '',
    this.coverUrl = '',
    this.churchType = 'Gospel',
    this.verificationStatus = 'unverified',
    this.memberCount = 0,
    this.branchCount = 0,
    this.followerCount = 0,
  });

  final String id;
  final String name;
  final String city;
  final bool verified;
  final String description;
  final String logoUrl;
  final String coverUrl;
  final String churchType;
  final String verificationStatus;
  final int memberCount;
  final int branchCount;
  final int followerCount;

  factory ChurchItem.fromJson(Map<String, dynamic> json) {
    return ChurchItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      verified: json['verified'] == true,
      description: json['description'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      churchType: json['churchType'] as String? ?? 'Gospel',
      verificationStatus: json['verificationStatus'] as String? ??
          ((json['verified'] == true) ? 'verified' : 'unverified'),
      memberCount:
          (json['memberCount'] as num? ?? json['member_count'] as num? ?? 0)
              .toInt(),
      branchCount:
          (json['branchCount'] as num? ?? json['branch_count'] as num? ?? 0)
              .toInt(),
      followerCount:
          (json['followerCount'] as num? ?? json['follower_count'] as num? ?? 0)
              .toInt(),
    );
  }
}

class ChurchMemberItem {
  const ChurchMemberItem({
    required this.churchId,
    required this.churchName,
    required this.city,
    required this.verified,
    required this.userId,
    required this.userFullName,
    required this.phoneNumber,
    required this.role,
    required this.joinedAt,
  });

  final String churchId;
  final String churchName;
  final String city;
  final bool verified;
  final String userId;
  final String userFullName;
  final String phoneNumber;
  final String role;
  final String joinedAt;

  factory ChurchMemberItem.fromJson(Map<String, dynamic> json) {
    return ChurchMemberItem(
      churchId: json['churchId'] as String? ?? '',
      churchName: json['churchName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      verified: json['verified'] == true,
      userId: json['userId'] as String? ?? '',
      userFullName: json['userFullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }
}

class UserDirectoryItem {
  const UserDirectoryItem({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.username,
    required this.language,
    required this.role,
    required this.createdAt,
    this.profileImage = '',
    this.followedByMe = false,
    this.blockedByMe = false,
    this.blockedMe = false,
    this.friendStatus = '',
    this.friendRequestId = '',
    this.friendRequestedByMe = false,
  });

  final String id;
  final String fullName;
  final String phoneNumber;
  final String username;
  final String language;
  final String role;
  final String createdAt;
  final String profileImage;
  final bool followedByMe;
  final bool blockedByMe;
  final bool blockedMe;
  final String friendStatus;
  final String friendRequestId;
  final bool friendRequestedByMe;

  factory UserDirectoryItem.fromJson(Map<String, dynamic> json) {
    return UserDirectoryItem(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      username: json['username'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      role: json['role'] as String? ?? 'member',
      createdAt: json['createdAt'] as String? ?? '',
      profileImage: json['profileImage'] as String? ?? '',
      followedByMe: json['followedByMe'] == true,
      blockedByMe: json['blockedByMe'] == true,
      blockedMe: json['blockedMe'] == true,
      friendStatus: json['friendStatus'] as String? ?? '',
      friendRequestId: json['friendRequestId'] as String? ?? '',
      friendRequestedByMe: json['friendRequestedByMe'] == true,
    );
  }
}

class UserDirectoryPage {
  const UserDirectoryPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<UserDirectoryItem> items;
  final int total;
  final int limit;
  final int offset;

  factory UserDirectoryPage.fromJson(Map<String, dynamic> json) {
    return UserDirectoryPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(UserDirectoryItem.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 25,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

class GroupItem {
  const GroupItem({
    required this.id,
    required this.name,
    required this.category,
  });

  final String id;
  final String name;
  final String category;

  factory GroupItem.fromJson(Map<String, dynamic> json) {
    return GroupItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
    );
  }
}

class GroupMembershipItem {
  const GroupMembershipItem({
    required this.groupId,
    required this.groupName,
    required this.category,
    required this.userId,
    required this.userFullName,
    required this.phoneNumber,
    required this.role,
    required this.joinedAt,
  });

  final String groupId;
  final String groupName;
  final String category;
  final String userId;
  final String userFullName;
  final String phoneNumber;
  final String role;
  final String joinedAt;

  factory GroupMembershipItem.fromJson(Map<String, dynamic> json) {
    return GroupMembershipItem(
      groupId: json['groupId'] as String? ?? '',
      groupName: json['groupName'] as String? ?? '',
      category: json['category'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userFullName: json['userFullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }
}

class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.location,
    required this.startsAt,
    this.description = '',
    this.endsAt = '',
    this.organizer = '',
    this.organizerType = '',
    this.category = '',
    this.eventType = '',
    this.capacity = 0,
    this.registrationType = '',
    this.ticketType = 'free',
    this.ticketPrice = 0,
    this.contactPerson = '',
    this.livestreamUrl = '',
    this.registrationCount = 0,
    this.attendanceCount = 0,
    this.registeredByMe = false,
    this.savedByMe = false,
  });

  final String id;
  final String title;
  final String location;
  final String startsAt;
  final String description;
  final String endsAt;
  final String organizer;
  final String organizerType;
  final String category;
  final String eventType;
  final int capacity;
  final String registrationType;
  final String ticketType;
  final num ticketPrice;
  final String contactPerson;
  final String livestreamUrl;
  final int registrationCount;
  final int attendanceCount;
  final bool registeredByMe;
  final bool savedByMe;

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      location: json['location'] as String? ?? '',
      startsAt: json['startsAt'] as String? ?? '',
      description: json['description'] as String? ?? '',
      endsAt: json['endsAt'] as String? ?? '',
      organizer: json['organizer'] as String? ?? '',
      organizerType: json['organizerType'] as String? ?? '',
      category: json['category'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      capacity: json['capacity'] as int? ?? 0,
      registrationType: json['registrationType'] as String? ?? '',
      ticketType: json['ticketType'] as String? ?? 'free',
      ticketPrice: _jsonNumber(json['ticketPrice']),
      contactPerson: json['contactPerson'] as String? ?? '',
      livestreamUrl: json['livestreamUrl'] as String? ?? '',
      registrationCount: json['registrationCount'] as int? ?? 0,
      attendanceCount: json['attendanceCount'] as int? ?? 0,
      registeredByMe: json['registeredByMe'] as bool? ?? false,
      savedByMe: json['savedByMe'] as bool? ?? false,
    );
  }
}

class EventRegistrationItem {
  const EventRegistrationItem({
    required this.eventId,
    required this.userId,
    required this.userFullName,
    required this.checkedInAt,
    required this.createdAt,
    this.status = 'registered',
    this.ticketCode = '',
    this.qrPayload = '',
  });

  final String eventId;
  final String userId;
  final String userFullName;
  final String? checkedInAt;
  final String createdAt;
  final String status;
  final String ticketCode;
  final String qrPayload;

  factory EventRegistrationItem.fromJson(Map<String, dynamic> json) {
    return EventRegistrationItem(
      eventId: json['eventId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userFullName: json['userFullName'] as String? ?? '',
      checkedInAt: json['checkedInAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      status: json['status'] as String? ?? 'registered',
      ticketCode: json['ticketCode'] as String? ?? '',
      qrPayload: json['qrPayload'] as String? ?? '',
    );
  }
}

class ChurchAnnouncementItem {
  const ChurchAnnouncementItem({
    required this.id,
    required this.churchId,
    required this.churchName,
    required this.city,
    required this.title,
    required this.body,
    required this.priority,
    required this.createdAt,
  });

  final String id;
  final String churchId;
  final String churchName;
  final String city;
  final String title;
  final String body;
  final String priority;
  final String createdAt;

  factory ChurchAnnouncementItem.fromJson(Map<String, dynamic> json) {
    return ChurchAnnouncementItem(
      id: json['id'] as String? ?? '',
      churchId: json['churchId'] as String? ?? '',
      churchName: json['churchName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      priority: json['priority'] as String? ?? 'normal',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class PrayerJournalItem {
  const PrayerJournalItem({
    required this.id,
    required this.title,
    required this.body,
    required this.answer,
    required this.answeredAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? answer;
  final String? answeredAt;
  final String createdAt;

  bool get answered => answer != null && answer!.trim().isNotEmpty;

  factory PrayerJournalItem.fromJson(Map<String, dynamic> json) {
    return PrayerJournalItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      answer: json['answer'] as String?,
      answeredAt: json['answeredAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class BibleSearchResultItem {
  const BibleSearchResultItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.language,
    required this.createdAt,
  });

  final String kind;
  final String title;
  final String subtitle;
  final String language;
  final String createdAt;

  factory BibleSearchResultItem.fromJson(Map<String, dynamic> json) {
    return BibleSearchResultItem(
      kind: json['kind'] as String? ?? 'verse',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class PrayerRequestItem {
  const PrayerRequestItem({
    required this.id,
    required this.requesterName,
    required this.title,
    required this.body,
    required this.status,
    required this.anonymous,
    required this.createdAt,
  });

  final String id;
  final String requesterName;
  final String title;
  final String body;
  final String status;
  final bool anonymous;
  final String createdAt;

  factory PrayerRequestItem.fromJson(Map<String, dynamic> json) {
    return PrayerRequestItem(
      id: json['id'] as String? ?? '',
      requesterName: json['requesterName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      anonymous: json['anonymous'] == true,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class PrayerChainItem {
  const PrayerChainItem({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.creatorName,
    required this.memberCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String createdBy;
  final String creatorName;
  final int memberCount;
  final String createdAt;

  factory PrayerChainItem.fromJson(Map<String, dynamic> json) {
    return PrayerChainItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      creatorName: json['creatorName'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class PrayerChainMemberItem {
  const PrayerChainMemberItem({
    required this.chainId,
    required this.userId,
    required this.userName,
    required this.joinedAt,
  });

  final String chainId;
  final String userId;
  final String userName;
  final String joinedAt;

  factory PrayerChainMemberItem.fromJson(Map<String, dynamic> json) {
    return PrayerChainMemberItem(
      chainId: json['chainId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }
}

class PrayerChainPostItem {
  const PrayerChainPostItem({
    required this.id,
    required this.chainId,
    required this.userId,
    required this.userName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String chainId;
  final String userId;
  final String userName;
  final String body;
  final String createdAt;

  factory PrayerChainPostItem.fromJson(Map<String, dynamic> json) {
    return PrayerChainPostItem(
      id: json['id'] as String? ?? '',
      chainId: json['chainId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class GrowthChallengeItem {
  const GrowthChallengeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.targetDays,
    required this.category,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final int targetDays;
  final String category;
  final String createdAt;

  factory GrowthChallengeItem.fromJson(Map<String, dynamic> json) {
    return GrowthChallengeItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetDays: (json['targetDays'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class GrowthSummaryItem {
  const GrowthSummaryItem({
    required this.prayerStreak,
    required this.bibleStreak,
    required this.serviceStreak,
    required this.totalCheckins,
    required this.level,
    required this.badges,
  });

  final int prayerStreak;
  final int bibleStreak;
  final int serviceStreak;
  final int totalCheckins;
  final String level;
  final List<String> badges;

  factory GrowthSummaryItem.fromJson(Map<String, dynamic> json) {
    return GrowthSummaryItem(
      prayerStreak: (json['prayerStreak'] as num?)?.toInt() ?? 0,
      bibleStreak: (json['bibleStreak'] as num?)?.toInt() ?? 0,
      serviceStreak: (json['serviceStreak'] as num?)?.toInt() ?? 0,
      totalCheckins: (json['totalCheckins'] as num?)?.toInt() ?? 0,
      level: json['level'] as String? ?? 'New Believer',
      badges: (json['badges'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }
}

class MinistryItem {
  const MinistryItem({
    required this.id,
    required this.name,
    required this.department,
    required this.description,
    required this.leadName,
    required this.createdAt,
    this.churchId = '',
    this.churchName = '',
    this.branchName = '',
    this.ministryType = 'department',
    this.memberCount = 0,
    this.followerCount = 0,
    this.followedByMe = false,
  });

  final String id;
  final String name;
  final String department;
  final String description;
  final String leadName;
  final String createdAt;
  final String churchId;
  final String churchName;
  final String branchName;
  final String ministryType;
  final int memberCount;
  final int followerCount;
  final bool followedByMe;

  factory MinistryItem.fromJson(Map<String, dynamic> json) {
    return MinistryItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      description: json['description'] as String? ?? '',
      leadName: json['leadName'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      churchId: json['churchId'] as String? ?? '',
      churchName: json['churchName'] as String? ?? '',
      branchName: json['branchName'] as String? ?? '',
      ministryType: json['ministryType'] as String? ?? 'department',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      followerCount:
          (json['followerCount'] as num? ?? json['follower_count'] as num? ?? 0)
              .toInt(),
      followedByMe:
          json['followedByMe'] == true || json['followed_by_me'] == true,
    );
  }
}

class UserMinistryMembershipItem {
  const UserMinistryMembershipItem({
    required this.ministryId,
    required this.ministryName,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  final String ministryId;
  final String ministryName;
  final String userId;
  final String role;
  final String joinedAt;

  factory UserMinistryMembershipItem.fromJson(Map<String, dynamic> json) {
    return UserMinistryMembershipItem(
      ministryId: json['ministryId'] as String? ?? '',
      ministryName: json['ministryName'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }
}

class MinistryMemberItem {
  const MinistryMemberItem({
    required this.ministryId,
    required this.ministryName,
    required this.userId,
    required this.userFullName,
    required this.role,
    required this.joinedAt,
  });

  final String ministryId;
  final String ministryName;
  final String userId;
  final String userFullName;
  final String role;
  final String joinedAt;

  factory MinistryMemberItem.fromJson(Map<String, dynamic> json) {
    return MinistryMemberItem(
      ministryId: json['ministryId'] as String? ?? '',
      ministryName: json['ministryName'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userFullName: json['userFullName'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }
}

class MinistryTaskItem {
  const MinistryTaskItem({
    required this.id,
    required this.ministryId,
    required this.ministryName,
    required this.title,
    required this.assigneeId,
    required this.assigneeName,
    required this.status,
    required this.dueDate,
    required this.createdAt,
  });

  final String id;
  final String ministryId;
  final String ministryName;
  final String title;
  final String? assigneeId;
  final String? assigneeName;
  final String status;
  final String? dueDate;
  final String createdAt;

  factory MinistryTaskItem.fromJson(Map<String, dynamic> json) {
    return MinistryTaskItem(
      id: json['id'] as String? ?? '',
      ministryId: json['ministryId'] as String? ?? '',
      ministryName: json['ministryName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      assigneeId: json['assigneeId'] as String?,
      assigneeName: json['assigneeName'] as String?,
      status: json['status'] as String? ?? 'open',
      dueDate: json['dueDate'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class MinistryResourceItem {
  const MinistryResourceItem({
    required this.id,
    required this.ministryId,
    required this.ministryName,
    required this.title,
    required this.url,
    required this.createdAt,
  });

  final String id;
  final String ministryId;
  final String ministryName;
  final String title;
  final String url;
  final String createdAt;

  factory MinistryResourceItem.fromJson(Map<String, dynamic> json) {
    return MinistryResourceItem(
      id: json['id'] as String? ?? '',
      ministryId: json['ministryId'] as String? ?? '',
      ministryName: json['ministryName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class MinistryChatItem {
  const MinistryChatItem({
    required this.id,
    required this.ministryId,
    required this.ministryName,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String ministryId;
  final String ministryName;
  final String authorId;
  final String authorName;
  final String body;
  final String createdAt;

  factory MinistryChatItem.fromJson(Map<String, dynamic> json) {
    return MinistryChatItem(
      id: json['id'] as String? ?? '',
      ministryId: json['ministryId'] as String? ?? '',
      ministryName: json['ministryName'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class MinistryAttendanceItem {
  const MinistryAttendanceItem({
    required this.id,
    required this.ministryId,
    required this.ministryName,
    required this.userId,
    required this.userName,
    required this.attendedOn,
    required this.createdAt,
  });

  final String id;
  final String ministryId;
  final String ministryName;
  final String userId;
  final String userName;
  final String attendedOn;
  final String createdAt;

  factory MinistryAttendanceItem.fromJson(Map<String, dynamic> json) {
    return MinistryAttendanceItem(
      id: json['id'] as String? ?? '',
      ministryId: json['ministryId'] as String? ?? '',
      ministryName: json['ministryName'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      attendedOn: json['attendedOn'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class MentorItem {
  const MentorItem({
    required this.id,
    required this.fullName,
    required this.ministry,
    required this.churchName,
    required this.languages,
    required this.verified,
    required this.followedByMe,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String ministry;
  final String churchName;
  final String languages;
  final bool verified;
  final bool followedByMe;
  final String createdAt;

  factory MentorItem.fromJson(Map<String, dynamic> json) {
    return MentorItem(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      ministry: json['ministry'] as String? ?? '',
      churchName: json['churchName'] as String? ?? '',
      languages: json['languages'] as String? ?? '',
      verified: json['verified'] == true,
      followedByMe: json['followedByMe'] == true,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class MentorshipRequestItem {
  const MentorshipRequestItem({
    required this.id,
    required this.mentorName,
    required this.requesterName,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String mentorName;
  final String requesterName;
  final String note;
  final String status;
  final String createdAt;

  factory MentorshipRequestItem.fromJson(Map<String, dynamic> json) {
    return MentorshipRequestItem(
      id: json['id'] as String? ?? '',
      mentorName: json['mentorName'] as String? ?? '',
      requesterName: json['requesterName'] as String? ?? '',
      note: json['note'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class BibleDailyVerseItem {
  const BibleDailyVerseItem({
    required this.id,
    required this.reference,
    required this.verseText,
    required this.referenceAm,
    required this.verseTextAm,
    required this.language,
    required this.theme,
    required this.createdAt,
    required this.dayOffset,
  });

  final String id;
  final String reference;
  final String verseText;
  final String referenceAm;
  final String verseTextAm;
  final String language;
  final String theme;
  final String createdAt;

  /// 0 = today, 1 = yesterday, 2 = two days ago.
  final int dayOffset;

  /// Reference in the requested [langCode], falling back to English.
  String referenceFor(String langCode) =>
      langCode == 'am' && referenceAm.isNotEmpty ? referenceAm : reference;

  /// Verse text in the requested [langCode], falling back to English.
  String textFor(String langCode) =>
      langCode == 'am' && verseTextAm.isNotEmpty ? verseTextAm : verseText;

  /// Whether an Amharic rendering exists for this verse.
  bool get hasAmharic => verseTextAm.isNotEmpty;

  factory BibleDailyVerseItem.fromJson(Map<String, dynamic> json) {
    return BibleDailyVerseItem(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      verseText: json['verseText'] as String? ?? '',
      referenceAm: json['referenceAm'] as String? ?? '',
      verseTextAm: json['verseTextAm'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      theme: json['theme'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      dayOffset: (json['dayOffset'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A reading group — a chat-enabled group (category `bible_study`) bound to a
/// reading plan, so members read the plan together while using the group's
/// chat, audio calls and notifications.
class BibleStudyGroupItem {
  const BibleStudyGroupItem({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.myRole,
    required this.visibility,
    required this.isMember,
    required this.lastActivityAt,
    required this.planTitle,
    required this.durationDays,
    required this.completedDays,
  });

  final String id;
  final String name;
  final String description;
  final int memberCount;
  final String myRole; // owner / admin / member / '' when not a member
  final String visibility; // public / private
  final bool isMember;
  final String lastActivityAt;
  final String planTitle;
  final int durationDays;
  final int completedDays;

  bool get isPrivate => visibility == 'private';
  bool get canManage => myRole == 'owner' || myRole == 'admin';
  bool get hasPlan => durationDays > 0 && planTitle.isNotEmpty;
  double get progress =>
      durationDays > 0 ? (completedDays / durationDays).clamp(0.0, 1.0) : 0.0;

  factory BibleStudyGroupItem.fromJson(Map<String, dynamic> json) {
    return BibleStudyGroupItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      myRole: json['myRole'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'public',
      isMember: json['isMember'] as bool? ?? false,
      lastActivityAt: json['lastActivityAt'] as String? ?? '',
      planTitle: json['planTitle'] as String? ?? '',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      completedDays: (json['completedDays'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The reading-plan state for a reading group — powers the in-group banner.
class ReadingGroupPlan {
  const ReadingGroupPlan({
    required this.planId,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.completedDays,
    required this.currentDay,
    required this.streak,
    required this.todayAssignment,
    required this.membersOnTrack,
    required this.memberCount,
    required this.isEnrolled,
  });

  final String planId;
  final String title;
  final String description;
  final int durationDays;
  final int completedDays;
  final int currentDay;
  final int streak;
  final String todayAssignment;
  final int membersOnTrack;
  final int memberCount;
  final bool isEnrolled;

  bool get isComplete => durationDays > 0 && completedDays >= durationDays;
  bool get todayDone => completedDays >= currentDay;
  double get progress =>
      durationDays > 0 ? (completedDays / durationDays).clamp(0.0, 1.0) : 0.0;

  factory ReadingGroupPlan.fromJson(Map<String, dynamic> json) {
    return ReadingGroupPlan(
      planId: json['planId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      completedDays: (json['completedDays'] as num?)?.toInt() ?? 0,
      currentDay: (json['currentDay'] as num?)?.toInt() ?? 1,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      todayAssignment: json['todayAssignment'] as String? ?? '',
      membersOnTrack: (json['membersOnTrack'] as num?)?.toInt() ?? 0,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      isEnrolled: json['isEnrolled'] as bool? ?? false,
    );
  }
}

class BibleReadingPlanItem {
  const BibleReadingPlanItem({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.language,
    required this.category,
    required this.createdAt,
    required this.joined,
    required this.completedDays,
    required this.isPersonal,
  });

  final String id;
  final String title;
  final String description;
  final int durationDays;
  final String language;
  final String category;
  final String createdAt;
  final bool joined;
  final int completedDays;
  final bool isPersonal;

  int get nextDay =>
      durationDays > 0 ? (completedDays + 1).clamp(1, durationDays) : 1;
  bool get isComplete => durationDays > 0 && completedDays >= durationDays;
  double get progress =>
      durationDays > 0 ? (completedDays / durationDays).clamp(0.0, 1.0) : 0.0;

  factory BibleReadingPlanItem.fromJson(Map<String, dynamic> json) {
    return BibleReadingPlanItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      language: json['language'] as String? ?? 'en',
      category: json['category'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      joined: json['joined'] as bool? ?? false,
      completedDays: (json['completedDays'] as num?)?.toInt() ?? 0,
      isPersonal: json['isPersonal'] as bool? ?? false,
    );
  }
}

class BibleBookmarkItem {
  const BibleBookmarkItem({
    required this.id,
    required this.reference,
    required this.verseText,
    required this.language,
    required this.createdAt,
  });

  final String id;
  final String reference;
  final String verseText;
  final String language;
  final String createdAt;

  factory BibleBookmarkItem.fromJson(Map<String, dynamic> json) {
    return BibleBookmarkItem(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      verseText: json['verseText'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class BibleHighlightItem {
  const BibleHighlightItem({
    required this.id,
    required this.reference,
    required this.verseText,
    required this.color,
    required this.note,
    required this.language,
    required this.createdAt,
  });

  final String id;
  final String reference;
  final String verseText;
  final String color;
  final String note;
  final String language;
  final String createdAt;

  factory BibleHighlightItem.fromJson(Map<String, dynamic> json) {
    return BibleHighlightItem(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      verseText: json['verseText'] as String? ?? '',
      color: json['color'] as String? ?? 'gold',
      note: json['note'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class BibleNoteItem {
  const BibleNoteItem({
    required this.id,
    required this.reference,
    required this.verseText,
    required this.note,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reference;
  final String verseText;
  final String note;
  final String language;
  final String createdAt;
  final String updatedAt;

  factory BibleNoteItem.fromJson(Map<String, dynamic> json) {
    return BibleNoteItem(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      verseText: json['verseText'] as String? ?? '',
      note: json['note'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class StoryItem {
  const StoryItem({
    required this.id,
    required this.authorName,
    required this.title,
    required this.body,
    required this.language,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String title;
  final String body;
  final String language;
  final String createdAt;

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: json['id'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class OpportunityItem {
  const OpportunityItem({
    required this.id,
    required this.title,
    required this.organization,
    required this.type,
    required this.location,
    required this.description,
    required this.deadline,
    required this.contactUrl,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String organization;
  final String type;
  final String location;
  final String description;
  final String deadline;
  final String contactUrl;
  final String createdAt;

  factory OpportunityItem.fromJson(Map<String, dynamic> json) {
    return OpportunityItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      type: json['type'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deadline: json['deadline'] as String? ?? '',
      contactUrl: json['contactUrl'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class OpportunityApplicationItem {
  const OpportunityApplicationItem({
    required this.id,
    required this.opportunityId,
    required this.opportunityTitle,
    required this.organization,
    required this.type,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String opportunityId;
  final String opportunityTitle;
  final String organization;
  final String type;
  final String note;
  final String status;
  final String createdAt;

  factory OpportunityApplicationItem.fromJson(Map<String, dynamic> json) {
    return OpportunityApplicationItem(
      id: json['id'] as String? ?? '',
      opportunityId: json['opportunityId'] as String? ?? '',
      opportunityTitle: json['opportunityTitle'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      type: json['type'] as String? ?? '',
      note: json['note'] as String? ?? '',
      status: json['status'] as String? ?? 'applied',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    required this.channel,
    required this.description,
    required this.url,
    required this.language,
    required this.featured,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String type;
  final String channel;
  final String description;
  final String url;
  final String language;
  final bool featured;
  final String createdAt;

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      featured: json['featured'] == true,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class TalentProfileItem {
  const TalentProfileItem({
    required this.userId,
    required this.fullName,
    required this.displayName,
    required this.category,
    required this.churchName,
    required this.city,
    required this.bio,
    required this.contactInfo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String userId;
  final String fullName;
  final String displayName;
  final String category;
  final String churchName;
  final String city;
  final String bio;
  final String contactInfo;
  final String createdAt;
  final String updatedAt;

  factory TalentProfileItem.fromJson(Map<String, dynamic> json) {
    return TalentProfileItem(
      userId: json['userId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      category: json['category'] as String? ?? '',
      churchName: json['churchName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      contactInfo: json['contactInfo'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class TalentCompetitionItem {
  const TalentCompetitionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.deadline,
    required this.entryCount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String deadline;
  final int entryCount;
  final String createdAt;

  factory TalentCompetitionItem.fromJson(Map<String, dynamic> json) {
    return TalentCompetitionItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      deadline: json['deadline'] as String? ?? '',
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class MarketplaceListingItem {
  const MarketplaceListingItem({
    required this.id,
    required this.title,
    required this.category,
    required this.priceCents,
    required this.sellerName,
    required this.active,
    required this.createdAt,
    this.sellerId = '',
    this.description = '',
    this.condition = '',
    this.location = '',
    this.phoneNumber = '',
    this.imageUrl = '',
    this.listingType = 'catalog',
  });

  final String id;
  final String title;
  final String category;
  final int priceCents;
  final String sellerName;
  final bool active;
  final String createdAt;
  final String sellerId;
  final String description;
  final String condition;
  final String location;
  final String phoneNumber;
  final String imageUrl;
  final String listingType;

  double get price => priceCents / 100;

  factory MarketplaceListingItem.fromJson(Map<String, dynamic> json) {
    return MarketplaceListingItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      priceCents:
          (json['price_cents'] as num? ?? json['priceCents'] as num? ?? 0)
              .toInt(),
      sellerName: json['seller_display_name'] as String? ??
          json['seller_name'] as String? ??
          json['sellerName'] as String? ??
          '',
      active: json['active'] != false,
      createdAt:
          json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
      sellerId:
          json['seller_id'] as String? ?? json['sellerId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      location: json['location'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ??
          json['phoneNumber'] as String? ??
          '',
      imageUrl:
          json['image_url'] as String? ?? json['imageUrl'] as String? ?? '',
      listingType: json['listing_type'] as String? ??
          json['listingType'] as String? ??
          'catalog',
    );
  }
}

class MarketplaceOrderItem {
  const MarketplaceOrderItem({
    required this.id,
    required this.userId,
    required this.listingId,
    required this.status,
    required this.receiptNumber,
    required this.createdAt,
    this.title = '',
    this.category = '',
    this.priceCents = 0,
  });

  final String id;
  final String userId;
  final String listingId;
  final String status;
  final String receiptNumber;
  final String createdAt;
  final String title;
  final String category;
  final int priceCents;

  double get price => priceCents / 100;

  factory MarketplaceOrderItem.fromJson(Map<String, dynamic> json) {
    return MarketplaceOrderItem(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      listingId:
          json['listing_id'] as String? ?? json['listingId'] as String? ?? '',
      status: json['status'] as String? ?? 'paid',
      receiptNumber: json['receipt_number'] as String? ??
          json['receiptNumber'] as String? ??
          '',
      createdAt:
          json['created_at'] as String? ?? json['createdAt'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      priceCents:
          (json['price_cents'] as num? ?? json['priceCents'] as num? ?? 0)
              .toInt(),
    );
  }
}

class PaymentPlanItem {
  const PaymentPlanItem({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.currency,
    required this.recurring,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String amount;
  final String currency;
  final bool recurring;
  final String createdAt;

  factory PaymentPlanItem.fromJson(Map<String, dynamic> json) {
    return PaymentPlanItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: json['amount']?.toString() ?? '',
      currency: json['currency'] as String? ?? 'ETB',
      recurring: json['recurring'] == true,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class PaymentHistoryItem {
  const PaymentHistoryItem({
    required this.id,
    required this.userName,
    required this.planName,
    required this.purpose,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userName;
  final String? planName;
  final String purpose;
  final String amount;
  final String currency;
  final String status;
  final String createdAt;

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryItem(
      id: json['id'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      planName: json['planName'] as String?,
      purpose: json['purpose'] as String? ?? '',
      amount: json['amount']?.toString() ?? '',
      currency: json['currency'] as String? ?? 'ETB',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class CourtshipProfileItem {
  const CourtshipProfileItem({
    required this.userId,
    required this.fullName,
    required this.churchName,
    required this.city,
    required this.bio,
    required this.interests,
    required this.faithStatement,
    required this.ministryInvolvement,
    required this.lifeGoals,
    required this.marriageVision,
    required this.relationshipIntent,
    required this.verified,
    required this.visible,
    required this.createdAt,
  });

  final String userId;
  final String fullName;
  final String churchName;
  final String city;
  final String bio;
  final String interests;
  final String faithStatement;
  final String ministryInvolvement;
  final String lifeGoals;
  final String marriageVision;
  final String relationshipIntent;
  final bool verified;
  final bool visible;
  final String createdAt;

  factory CourtshipProfileItem.fromJson(Map<String, dynamic> json) {
    return CourtshipProfileItem(
      userId: json['userId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      churchName: json['churchName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      interests: json['interests'] as String? ?? '',
      faithStatement: json['faithStatement'] as String? ?? '',
      ministryInvolvement: json['ministryInvolvement'] as String? ?? '',
      lifeGoals: json['lifeGoals'] as String? ?? '',
      marriageVision: json['marriageVision'] as String? ?? '',
      relationshipIntent: json['relationshipIntent'] as String? ?? 'serious',
      verified: json['verified'] == true,
      visible: json['visible'] == true,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class CourtshipInterestItem {
  const CourtshipInterestItem({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String note;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory CourtshipInterestItem.fromJson(Map<String, dynamic> json) {
    return CourtshipInterestItem(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      receiverName: json['receiverName'] as String? ?? '',
      note: json['note'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class ModuleStatusItem {
  const ModuleStatusItem({required this.module, required this.ready});

  final String module;
  final bool ready;

  factory ModuleStatusItem.fromJson(Map<String, dynamic> json) {
    return ModuleStatusItem(
      module: json['module'] as String? ?? '',
      ready: json['ready'] == true,
    );
  }
}

class ChatMessageItem {
  const ChatMessageItem({
    required this.id,
    required this.room,
    required this.authorId,
    required this.authorFullName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String room;
  final String authorId;
  final String authorFullName;
  final String body;
  final String createdAt;

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] as String? ?? '',
      room: json['room'] as String? ?? 'general',
      authorId: json['authorId'] as String? ?? '',
      authorFullName: json['authorFullName'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.authorId,
    required this.author,
    required this.title,
    required this.body,
    required this.language,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.likedByMe,
    this.savedByMe = false,
    this.authorFollowedByMe = false,
    required this.hashtags,
    required this.mentions,
    this.postType = 'text',
    this.mediaUrls = const [],
    this.mediaType = '',
    this.repostOf,
    this.reactionCounts = const {},
    this.myReaction = '',
    this.pollQuestion = '',
    this.pollOptions = const [],
  });

  final String id;
  final String authorId;
  final String author;
  final String title;
  final String body;
  final String language;
  final String createdAt;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool likedByMe;
  final bool savedByMe;
  final bool authorFollowedByMe;
  final List<String> hashtags;
  final List<String> mentions;
  final String postType;
  final List<String> mediaUrls;
  final String mediaType;
  final String? repostOf;
  final Map<String, int> reactionCounts;
  final String myReaction;
  final String pollQuestion;
  final List<String> pollOptions;

  FeedItem copyWith({
    String? authorId,
    String? author,
    String? title,
    String? body,
    String? language,
    String? createdAt,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    bool? likedByMe,
    bool? savedByMe,
    bool? authorFollowedByMe,
    List<String>? hashtags,
    List<String>? mentions,
    String? postType,
    List<String>? mediaUrls,
    String? mediaType,
    String? repostOf,
    Map<String, int>? reactionCounts,
    String? myReaction,
    String? pollQuestion,
    List<String>? pollOptions,
  }) {
    return FeedItem(
      id: id,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      title: title ?? this.title,
      body: body ?? this.body,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      likedByMe: likedByMe ?? this.likedByMe,
      savedByMe: savedByMe ?? this.savedByMe,
      authorFollowedByMe: authorFollowedByMe ?? this.authorFollowedByMe,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      postType: postType ?? this.postType,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaType: mediaType ?? this.mediaType,
      repostOf: repostOf ?? this.repostOf,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      myReaction: myReaction ?? this.myReaction,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      pollOptions: pollOptions ?? this.pollOptions,
    );
  }

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      author: json['authorName'] as String? ?? json['author'] as String? ?? '',
      title: json['title'] as String? ?? json['body'] as String? ?? '',
      body: json['body'] as String? ?? json['title'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      createdAt: json['createdAt'] as String? ?? '',
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      likedByMe: json['likedByMe'] == true,
      savedByMe: json['savedByMe'] == true,
      authorFollowedByMe: json['authorFollowedByMe'] == true,
      hashtags: (json['hashtags'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      mentions: (json['mentions'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      postType: json['postType'] as String? ?? 'text',
      mediaUrls: (json['mediaUrls'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      mediaType: json['mediaType'] as String? ?? '',
      repostOf: json['repostOf'] as String?,
      reactionCounts:
          (json['reactionCounts'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      myReaction: json['myReaction'] as String? ?? '',
      pollQuestion: json['pollQuestion'] as String? ?? '',
      pollOptions: (json['pollOptions'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }
}

class PostCommentItem {
  const PostCommentItem({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String body;
  final String createdAt;

  factory PostCommentItem.fromJson(Map<String, dynamic> json) {
    return PostCommentItem(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class ChurchMembershipItem {
  const ChurchMembershipItem({
    required this.churchId,
    required this.churchName,
    required this.city,
    required this.verified,
    required this.role,
    required this.joinedAt,
  });

  final String churchId;
  final String churchName;
  final String city;
  final bool verified;
  final String role;
  final String joinedAt;

  factory ChurchMembershipItem.fromJson(Map<String, dynamic> json) {
    return ChurchMembershipItem(
      churchId: json['churchId'] as String? ?? '',
      churchName: json['churchName'] as String? ?? '',
      city: json['city'] as String? ?? '',
      verified: json['verified'] == true,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }
}

class ReportItem {
  const ReportItem({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final String targetType;
  final String targetId;
  final String reason;
  final String status;
  final String createdAt;

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    return ReportItem(
      id: json['id'] as String? ?? '',
      reporterId: json['reporterId'] as String? ?? '',
      targetType: json['targetType'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.username,
    required this.language,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String phoneNumber;
  final String username;
  final String language;
  final String role;
  final String createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      username: json['username'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      role: json['role'] as String? ?? 'member',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class AuthResult {
  const AuthResult({
    required this.token,
    required this.user,
    this.refreshToken = '',
    this.expiresAt = '',
  });

  final String token;
  final String refreshToken;
  final String expiresAt;
  final UserProfile user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
      user: UserProfile.fromJson(
          (json['user'] as Map<String, dynamic>? ?? const {})),
    );
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.bootstrap,
    required this.summary,
    required this.feed,
    required this.churches,
    required this.groups,
    required this.events,
  });

  final AppBootstrap bootstrap;
  final Map<String, int> summary;
  final List<FeedItem> feed;
  final List<ChurchItem> churches;
  final List<GroupItem> groups;
  final List<EventItem> events;
}

class GlobalSearchResultItem {
  const GlobalSearchResultItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });

  final String kind;
  final String id;
  final String title;
  final String subtitle;
  final String createdAt;

  factory GlobalSearchResultItem.fromJson(Map<String, dynamic> json) {
    return GlobalSearchResultItem(
      kind: json['kind'] as String? ?? '',
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.readAt,
    required this.createdAt,
    this.actorId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? targetType;
  final String? targetId;
  final String? readAt;
  final String createdAt;
  final String? actorId;

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as String?,
      readAt: json['readAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      actorId: json['actorId'] as String?,
    );
  }
}
