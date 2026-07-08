import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'app_models.dart';

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Future<DashboardSnapshot> loadDashboard({String? token}) async {
    final results = await Future.wait<dynamic>([
      fetchBootstrap(),
      fetchSummary(),
      fetchFeed(token: token),
      fetchChurches(),
      fetchGroups(),
      fetchEvents(),
    ]);

    return DashboardSnapshot(
      bootstrap: results[0] as AppBootstrap,
      summary: (results[1] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, (value as num).toInt())),
      feed: results[2] as List<FeedItem>,
      churches: results[3] as List<ChurchItem>,
      groups: results[4] as List<GroupItem>,
      events: results[5] as List<EventItem>,
    );
  }

  Future<AppBootstrap> fetchBootstrap() async {
    final response = await _getJson('/app/bootstrap');
    return AppBootstrap.fromJson(response as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> fetchSummary() async {
    final response = await _getJson('/app/summary');
    return response as Map<String, dynamic>;
  }

  Future<List<FeedItem>> fetchFeed({String? token}) async {
    final response = token == null
        ? await _getJson('/feed')
        : await _getJson(
            '/feed',
            headers: {'Authorization': 'Bearer $token'},
          );
    final items = response is Map<String, dynamic>
        ? response['items'] as List<dynamic>? ?? const <dynamic>[]
        : response as List<dynamic>;
    return items.cast<Map<String, dynamic>>().map(FeedItem.fromJson).toList();
  }

  Future<List<PostCommentItem>> fetchPostComments(String postId) async {
    final response = await _getJson('/posts/$postId/comments');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PostCommentItem.fromJson)
        .toList();
  }

  Future<PostCommentItem> createPostComment({
    required String token,
    required String postId,
    required String body,
  }) async {
    final response = await _postJson(
      '/posts/$postId/comments',
      {'body': body},
      headers: {'Authorization': 'Bearer $token'},
    );
    return PostCommentItem.fromJson(response as Map<String, dynamic>);
  }

  Future<dynamic> likePost({
    required String token,
    required String postId,
  }) async {
    return _postJson(
      '/posts/$postId/like',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> unlikePost({
    required String token,
    required String postId,
  }) async {
    return _deleteJson(
      '/posts/$postId/like',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> sharePost({
    required String token,
    required String postId,
  }) async {
    return _postJson(
      '/posts/$postId/share',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<ChurchItem>> fetchChurches() async {
    final response = await _getJson('/churches');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChurchItem.fromJson)
        .toList();
  }

  Future<List<ChurchItem>> searchChurches({
    String query = '',
    String city = '',
    String type = '',
    bool? verified,
  }) async {
    final parameters = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (city.trim().isNotEmpty) 'city': city.trim(),
      if (type.trim().isNotEmpty) 'type': type.trim(),
      if (verified != null) 'verified': '$verified',
    };
    final suffix = parameters.isEmpty
        ? ''
        : '?${parameters.entries.map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    final response = await _getJson('/churches$suffix');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChurchItem.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchChurchProfile(
    String churchId, {
    String? token,
  }) async {
    final response = token == null
        ? await _getJson('/churches/$churchId/profile')
        : await _getJson(
            '/churches/$churchId/profile',
            headers: {'Authorization': 'Bearer $token'},
          );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createChurch(
    String token,
    Map<String, dynamic> input,
  ) async {
    final response = await _postJson(
      '/churches',
      input,
      headers: {'Authorization': 'Bearer $token'},
    );
    return response as Map<String, dynamic>;
  }

  Future<dynamic> createChurchContent(
    String token,
    String churchId,
    String section,
    Map<String, dynamic> input,
  ) {
    return _postJson(
      '/churches/$churchId/$section',
      input,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> updateChurchContent(
    String token,
    String churchId,
    String section,
    String itemId,
    Map<String, dynamic> input,
  ) {
    return _patchJson(
      '/churches/$churchId/$section/$itemId',
      input,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> deleteChurchContent(
    String token,
    String churchId,
    String section,
    String itemId,
  ) {
    return _deleteJson(
      '/churches/$churchId/$section/$itemId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> uploadMediaAsset({
    required String token,
    required String usage,
    required String fileName,
    required String contentType,
    required int byteSize,
    required Uint8List bytes,
    String? scopeType,
    String? scopeId,
  }) async {
    final signed = await _postJson(
      '/media/upload-url',
      {
        'usage': usage,
        'fileName': fileName,
        'contentType': contentType,
        'byteSize': byteSize,
        if (scopeType != null) 'scopeType': scopeType,
        if (scopeId != null) 'scopeId': scopeId,
      },
      headers: {'Authorization': 'Bearer $token'},
    ) as Map<String, dynamic>;
    final uploadUrl = signed['uploadUrl'] as String? ?? '';
    final assetId = signed['assetId'] as String? ?? '';
    if (uploadUrl.isEmpty || assetId.isEmpty) {
      throw const ApiException('media_upload_url_invalid');
    }
    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'content-type': contentType,
        'content-length': byteSize.toString(),
      },
      body: bytes,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw ApiException('media_upload_failed: ${uploadResponse.statusCode}');
    }
    return await _postJson(
      '/media/$assetId/complete',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    ) as Map<String, dynamic>;
  }

  Future<dynamic> updateChurchProfile(
    String token,
    String churchId,
    Map<String, dynamic> input,
  ) {
    return _patchJson(
      '/churches/$churchId/profile',
      input,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> updateChurchLogo({
    required String token,
    required String churchId,
    required String url,
  }) {
    return _postJson(
      '/churches/$churchId/logo',
      {'url': url},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> updateChurchCover({
    required String token,
    required String churchId,
    required String url,
  }) {
    return _postJson(
      '/churches/$churchId/cover',
      {'url': url},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> requestChurchVerification(
    String token,
    String churchId,
    Map<String, dynamic> input,
  ) {
    return _postJson(
      '/churches/$churchId/verification-request',
      input,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> assignBranchAdmin({
    required String token,
    required String churchId,
    required String branchId,
    required String userId,
  }) {
    return _postJson(
      '/churches/$churchId/branches/$branchId/admins',
      {'userId': userId},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> joinChurchWithIntent({
    required String token,
    required String churchId,
    required String role,
    String visibility = 'members',
  }) {
    return _postJson(
      '/churches/$churchId/join',
      {'role': role, 'visibility': visibility},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<dynamic>> fetchChurchMembershipRequests(
    String token,
    String churchId,
  ) async {
    return (await _getJson(
      '/churches/$churchId/membership-requests',
      headers: {'Authorization': 'Bearer $token'},
    )) as List<dynamic>;
  }

  Future<dynamic> reviewChurchMembership(
    String token,
    String churchId,
    String membershipId,
    bool approve,
  ) {
    return _patchJson(
      '/church-memberships/$membershipId/${approve ? 'approve' : 'reject'}',
      {'churchId': churchId},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> fetchChurchAnalytics(
    String token,
    String churchId,
  ) async {
    return (await _getJson(
      '/churches/$churchId/analytics',
      headers: {'Authorization': 'Bearer $token'},
    )) as Map<String, dynamic>;
  }

  Future<dynamic> reactToPost(String token, String postId, String reaction) =>
      _postJson("/posts/$postId/reactions", {"reaction": reaction},
          headers: {"Authorization": "Bearer $token"});

  Future<dynamic> replyToComment(
          String token, String postId, String commentId, String body) =>
      _postJson("/posts/$postId/comments/$commentId/replies", {"body": body},
          headers: {"Authorization": "Bearer $token"});

  Future<dynamic> repostPost(
          String token, String postId, String caption, String language) =>
      _postJson(
          "/posts/$postId/repost", {"caption": caption, "language": language},
          headers: {"Authorization": "Bearer $token"});

  Future<dynamic> votePostPoll(String token, String postId, int optionIndex) =>
      _postJson("/posts/$postId/poll-votes", {"optionIndex": optionIndex},
          headers: {"Authorization": "Bearer $token"});

  Future<List<ChurchMemberItem>> fetchChurchMembers(String churchId) async {
    final response = await _getJson('/churches/$churchId/members');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChurchMemberItem.fromJson)
        .toList();
  }

  Future<List<ChurchBranchItem>> fetchChurchBranches(String churchId) async {
    final response = await _getJson('/churches/$churchId/branches');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChurchBranchItem.fromJson)
        .toList();
  }

  Future<List<ChurchScheduleItem>> fetchChurchSchedules(String churchId) async {
    final response = await _getJson('/churches/$churchId/schedules');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChurchScheduleItem.fromJson)
        .toList();
  }

  Future<List<SermonItem>> fetchChurchSermons(String churchId) async {
    final response = await _getJson('/churches/$churchId/sermons');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SermonItem.fromJson)
        .toList();
  }

  Future<UserDirectoryItem> fetchUserByUsername(String username) async {
    final response = await _getJson(
        '/users/username/${Uri.encodeComponent(username.trim().toLowerCase())}');
    return UserDirectoryItem.fromJson(response as Map<String, dynamic>);
  }

  Future<UserDirectoryPage> fetchUsersPage({
    String? token,
    String query = '',
    int limit = 25,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'paginated': 'true',
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (query.trim().isNotEmpty) 'q': query.trim(),
    };
    final path =
        '/users?${params.entries.map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    final response = await _getJson(path,
        headers: token == null || token.isEmpty
            ? const {}
            : {'Authorization': 'Bearer $token'});
    return UserDirectoryPage.fromJson(response as Map<String, dynamic>);
  }

  Future<List<UserDirectoryItem>> fetchUsers({String? token}) async {
    final response = await _getJson('/users',
        headers: token == null || token.isEmpty
            ? const {}
            : {'Authorization': 'Bearer $token'});
    if (response is Map<String, dynamic>) {
      return UserDirectoryPage.fromJson(response).items;
    }
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(UserDirectoryItem.fromJson)
        .toList();
  }

  Future<dynamic> followUser({
    required String token,
    required String userId,
  }) async {
    return _postJson(
      '/users/$userId/follow',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> unfollowUser({
    required String token,
    required String userId,
  }) async {
    return _deleteJson(
      '/users/$userId/follow',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> blockUser({
    required String token,
    required String userId,
  }) async {
    return _postJson(
      '/users/$userId/block',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> unblockUser({
    required String token,
    required String userId,
  }) async {
    return _deleteJson(
      '/users/$userId/block',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<GroupItem>> fetchGroups() async {
    final response = await _getJson('/groups');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(GroupItem.fromJson)
        .toList();
  }

  Future<GroupItem?> fetchGroupById(String groupId) async {
    final response = await _getJson('/groups/$groupId');
    if (response == null) {
      return null;
    }
    return GroupItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<GroupMembershipItem>> fetchGroupMembers(String groupId) async {
    final response = await _getJson('/groups/$groupId/members');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(GroupMembershipItem.fromJson)
        .toList();
  }

  Future<List<GroupMembershipItem>> fetchMyGroupMemberships(
      String token) async {
    final response = await _getJson(
      '/groups/me/memberships',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(GroupMembershipItem.fromJson)
        .toList();
  }

  Future<dynamic> joinGroup({
    required String token,
    required String groupId,
  }) async {
    return _postJson(
      '/groups/$groupId/join',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> leaveGroup({
    required String token,
    required String groupId,
  }) async {
    return _deleteJson(
      '/groups/$groupId/leave',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<EventItem>> fetchEvents() async {
    final response = await _getJson('/events');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(EventItem.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchEventsHome(String? token) async {
    final response = await _getJson(
      '/events/home',
      headers: token == null || token.isEmpty
          ? const {}
          : {'Authorization': 'Bearer $token'},
    );
    return (response as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> fetchEventDetail(
      String eventId, String? token) async {
    final response = await _getJson(
      '/events/$eventId',
      headers: token == null || token.isEmpty
          ? const {}
          : {'Authorization': 'Bearer $token'},
    );
    return (response as Map<String, dynamic>);
  }

  Future<List<EventRegistrationItem>> fetchEventRegistrations(
      String eventId) async {
    final response = await _getJson('/events/$eventId/registrations');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(EventRegistrationItem.fromJson)
        .toList();
  }

  Future<dynamic> registerForEvent({
    required String token,
    required String eventId,
    Map<String, dynamic> body = const {},
  }) async {
    return _postJson(
      '/events/$eventId/register',
      body,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> checkInForEvent({
    required String token,
    required String eventId,
  }) async {
    return _postJson(
      '/events/$eventId/check-in',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> saveEvent({required String token, required String eventId}) {
    return _postJson('/events/$eventId/save', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> applyEventVolunteer(
      {required String token,
      required String eventId,
      String role = 'media',
      String note = ''}) {
    return _postJson(
        '/events/$eventId/volunteers/apply', {'role': role, 'note': note},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> createEventTask(
      {required String token, required String eventId, required String title}) {
    return _postJson(
        '/events/$eventId/tasks', {'title': title, 'priority': 'normal'},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> createEventDiscussion(
      {required String token,
      required String eventId,
      required String title,
      String body = ''}) {
    return _postJson(
        '/events/$eventId/discussions', {'title': title, 'body': body},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> submitEventFeedback(
      {required String token,
      required String eventId,
      int rating = 5,
      String body = ''}) {
    return _postJson(
        '/events/$eventId/feedback', {'rating': rating, 'body': body},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<PrayerRequestItem>> fetchPrayerRequests() async {
    final response = await _getJson('/prayer/requests');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PrayerRequestItem.fromJson)
        .toList();
  }

  Future<List<ChurchAnnouncementItem>> fetchChurchAnnouncements(
      {String? churchId}) async {
    final response = await _getJson(churchId == null
        ? '/churches/announcements'
        : '/churches/$churchId/announcements');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChurchAnnouncementItem.fromJson)
        .toList();
  }

  Future<ChurchAnnouncementItem> createChurchAnnouncement({
    required String token,
    required String churchId,
    required String title,
    required String body,
    String priority = 'normal',
  }) async {
    final response = await _postJson(
      '/churches/$churchId/announcements',
      {'title': title, 'body': body, 'priority': priority},
      headers: {'Authorization': 'Bearer $token'},
    );
    return ChurchAnnouncementItem.fromJson(response as Map<String, dynamic>);
  }

  Future<PrayerRequestItem> createPrayerRequest({
    required String token,
    required String title,
    required String body,
    bool anonymous = false,
  }) async {
    final response = await _postJson(
      '/prayer/requests',
      {
        'title': title,
        'body': body,
        'anonymous': anonymous,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return PrayerRequestItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<PrayerChainItem>> fetchPrayerChains() async {
    final response = await _getJson('/prayer/chains');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PrayerChainItem.fromJson)
        .toList();
  }

  Future<List<PrayerChainMemberItem>> fetchPrayerChainMembers(
      String chainId) async {
    final response = await _getJson('/prayer/chains/$chainId/members');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PrayerChainMemberItem.fromJson)
        .toList();
  }

  Future<List<PrayerChainPostItem>> fetchPrayerChainPosts(
      String chainId) async {
    final response = await _getJson('/prayer/chains/$chainId/posts');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PrayerChainPostItem.fromJson)
        .toList();
  }

  Future<dynamic> joinPrayerChain({
    required String token,
    required String chainId,
  }) async {
    return _postJson(
      '/prayer/chains/$chainId/join',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> createPrayerChainPost({
    required String token,
    required String chainId,
    required String body,
  }) async {
    return _postJson(
      '/prayer/chains/$chainId/posts',
      {'body': body},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<GrowthChallengeItem>> fetchGrowthChallenges() async {
    final response = await _getJson('/growth/challenges');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(GrowthChallengeItem.fromJson)
        .toList();
  }

  Future<GrowthSummaryItem> fetchGrowthSummary(String token) async {
    final response = await _getJson(
      '/growth/summary',
      headers: {'Authorization': 'Bearer $token'},
    );
    return GrowthSummaryItem.fromJson(response as Map<String, dynamic>);
  }

  Future<dynamic> addGrowthCheckin({
    required String token,
    required String kind,
    String? checkedOn,
  }) async {
    return _postJson(
      '/growth/checkins',
      {
        'kind': kind,
        if (checkedOn != null) 'checkedOn': checkedOn,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<MinistryItem>> fetchMinistries({String? token}) async {
    final response = token == null || token.isEmpty
        ? await _getJson('/ministries')
        : await _getJson('/ministries',
            headers: {'Authorization': 'Bearer $token'});
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MinistryItem.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchMinistryProfile(
    String ministryId, {
    String? token,
  }) async {
    final response = token == null
        ? await _getJson('/ministries/$ministryId')
        : await _getJson('/ministries/$ministryId',
            headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<dynamic> createMinistryContent(
    String token,
    String ministryId,
    String section,
    Map<String, dynamic> input,
  ) {
    return _postJson(
      '/ministries/$ministryId/$section',
      input,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> updateMinistryContent(
    String token,
    String ministryId,
    String section,
    String itemId,
    Map<String, dynamic> input,
  ) {
    return _patchJson(
      '/ministries/$ministryId/$section/$itemId',
      input,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> deleteMinistryContent(
    String token,
    String ministryId,
    String section,
    String itemId,
  ) {
    return _deleteJson(
      '/ministries/$ministryId/$section/$itemId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> assignMinistryLeader({
    required String token,
    required String ministryId,
    required String userId,
    String role = 'leader',
  }) {
    return _postJson(
      '/ministries/$ministryId/leaders',
      {'userId': userId, 'role': role},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> joinMinistryWithReason({
    required String token,
    required String ministryId,
    String role = 'member',
    String reason = '',
  }) {
    return _postJson(
      '/ministries/$ministryId/join',
      {'role': role, 'reason': reason},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<dynamic>> fetchMinistryMemberRequests(
    String token,
    String ministryId,
  ) async {
    return (await _getJson('/ministries/$ministryId/member-requests',
        headers: {'Authorization': 'Bearer $token'})) as List<dynamic>;
  }

  Future<dynamic> reviewMinistryMembership(
    String token,
    String ministryId,
    String membershipId,
    bool approve,
  ) {
    return _patchJson(
      '/ministry-memberships/$membershipId/${approve ? 'approve' : 'reject'}',
      {'ministryId': ministryId},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> fetchMinistryAnalytics(
    String token,
    String ministryId,
  ) async {
    return (await _getJson('/ministries/$ministryId/analytics',
        headers: {'Authorization': 'Bearer $token'})) as Map<String, dynamic>;
  }

  Future<dynamic> completeMinistryTask(String token, String taskId) {
    return _postJson('/tasks/$taskId/complete', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<UserMinistryMembershipItem>> fetchMyMinistryMemberships(
      String token) async {
    final response = await _getJson(
      '/ministries/me/memberships',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(UserMinistryMembershipItem.fromJson)
        .toList();
  }

  Future<List<MinistryMemberItem>> fetchMinistryMembers(
      String ministryId) async {
    final response = await _getJson('/ministries/$ministryId/members');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MinistryMemberItem.fromJson)
        .toList();
  }

  Future<List<MinistryTaskItem>> fetchMinistryTasks(String ministryId) async {
    final response = await _getJson('/ministries/$ministryId/tasks');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MinistryTaskItem.fromJson)
        .toList();
  }

  Future<dynamic> createMinistryTask({
    required String token,
    required String ministryId,
    required String title,
    String? assigneeId,
    String? dueDate,
  }) async {
    return _postJson(
      '/ministries/$ministryId/tasks',
      {
        'title': title,
        if (assigneeId != null) 'assigneeId': assigneeId,
        if (dueDate != null) 'dueDate': dueDate,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<MinistryResourceItem>> fetchMinistryResources(
      String ministryId) async {
    final response = await _getJson('/ministries/$ministryId/resources');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MinistryResourceItem.fromJson)
        .toList();
  }

  Future<List<MinistryChatItem>> fetchMinistryChats(String ministryId) async {
    final response = await _getJson('/ministries/$ministryId/chats');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MinistryChatItem.fromJson)
        .toList();
  }

  Future<dynamic> createMinistryChat({
    required String token,
    required String ministryId,
    required String body,
  }) async {
    return _postJson(
      '/ministries/$ministryId/chats',
      {'body': body},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<MinistryAttendanceItem>> fetchMinistryAttendance(
      String ministryId) async {
    final response = await _getJson('/ministries/$ministryId/attendance');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MinistryAttendanceItem.fromJson)
        .toList();
  }

  Future<dynamic> markMinistryAttendance({
    required String token,
    required String ministryId,
    String? attendedOn,
  }) async {
    return _postJson(
      '/ministries/$ministryId/attendance',
      {
        if (attendedOn != null) 'attendedOn': attendedOn,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> joinMinistry({
    required String token,
    required String ministryId,
  }) async {
    return _postJson(
      '/ministries/$ministryId/join',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> leaveMinistry({
    required String token,
    required String ministryId,
  }) async {
    return _deleteJson(
      '/ministries/$ministryId/leave',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> followMinistry({
    required String token,
    required String ministryId,
  }) async {
    return _postJson(
      '/ministries/$ministryId/follow',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> unfollowMinistry({
    required String token,
    required String ministryId,
  }) async {
    return _deleteJson(
      '/ministries/$ministryId/follow',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<MentorItem>> fetchMentors({String? token}) async {
    final response = token == null
        ? await _getJson('/mentors')
        : await _getJson('/mentors',
            headers: {'Authorization': 'Bearer $token'});
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MentorItem.fromJson)
        .toList();
  }

  Future<dynamic> followMentor(
      {required String token, required String mentorId}) async {
    return _postJson('/mentors/$mentorId/follow', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> unfollowMentor(
      {required String token, required String mentorId}) async {
    return _deleteJson('/mentors/$mentorId/follow',
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<MentorshipRequestItem>> fetchMentorshipRequests(
      String token) async {
    final response = await _getJson(
      '/mentorship/requests',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MentorshipRequestItem.fromJson)
        .toList();
  }

  Future<MentorshipRequestItem> createMentorshipRequest({
    required String token,
    required String mentorId,
    required String note,
  }) async {
    final response = await _postJson(
      '/mentorship/requests',
      {
        'mentorId': mentorId,
        'note': note,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return MentorshipRequestItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<StoryItem>> fetchStories() async {
    final response = await _getJson('/stories');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(StoryItem.fromJson)
        .toList();
  }

  Future<StoryItem> createStory({
    required String token,
    required String title,
    required String body,
    required String language,
  }) async {
    final response = await _postJson(
      '/stories',
      {
        'title': title,
        'body': body,
        'language': language,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return StoryItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<OpportunityItem>> fetchOpportunities() async {
    final response = await _getJson('/opportunities');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(OpportunityItem.fromJson)
        .toList();
  }

  Future<List<OpportunityApplicationItem>> fetchMyOpportunityApplications(
      String token) async {
    final response = await _getJson(
      '/opportunities/me/applications',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(OpportunityApplicationItem.fromJson)
        .toList();
  }

  Future<OpportunityApplicationItem> applyForOpportunity({
    required String token,
    required String opportunityId,
    required String note,
  }) async {
    final response = await _postJson(
      '/opportunities/$opportunityId/apply',
      {'note': note},
      headers: {'Authorization': 'Bearer $token'},
    );
    return OpportunityApplicationItem.fromJson(
        response as Map<String, dynamic>);
  }

  Future<List<MediaItem>> fetchMediaItems() async {
    final response = await _getJson('/media');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MediaItem.fromJson)
        .toList();
  }

  Future<List<TalentProfileItem>> fetchTalentProfiles() async {
    final response = await _getJson('/talent/profiles');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TalentProfileItem.fromJson)
        .toList();
  }

  Future<TalentProfileItem?> fetchTalentMe(String token) async {
    final response = await _getJson(
      '/talent/me',
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response == null) {
      return null;
    }
    return TalentProfileItem.fromJson(response as Map<String, dynamic>);
  }

  Future<TalentProfileItem> upsertTalentProfile({
    required String token,
    required String displayName,
    required String category,
    required String churchName,
    required String city,
    required String bio,
    required String contactInfo,
  }) async {
    final response = await _putJson(
      '/talent/me',
      {
        'displayName': displayName,
        'category': category,
        'churchName': churchName,
        'city': city,
        'bio': bio,
        'contactInfo': contactInfo,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return TalentProfileItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<TalentCompetitionItem>> fetchTalentCompetitions() async {
    final response = await _getJson('/talent/competitions');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TalentCompetitionItem.fromJson)
        .toList();
  }

  Future<void> enterTalentCompetition({
    required String token,
    required String competitionId,
  }) async {
    await _postJson(
      '/talent/competitions/$competitionId/enter',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<PaymentPlanItem>> fetchPaymentPlans() async {
    final response = await _getJson('/payments/plans');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentPlanItem.fromJson)
        .toList();
  }

  Future<List<PaymentHistoryItem>> fetchPaymentHistory(String token) async {
    final response = await _getJson(
      '/payments/history',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentHistoryItem.fromJson)
        .toList();
  }

  Future<List<BibleDailyVerseItem>> fetchDailyVerses() async {
    final response = await _getJson('/bible/daily-verses');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(BibleDailyVerseItem.fromJson)
        .toList();
  }

  Future<List<BibleSearchResultItem>> searchBible(String query,
      {String? token}) async {
    final response = token == null
        ? await _getJson('/bible/search?q=${Uri.encodeQueryComponent(query)}')
        : await _getJson('/bible/search?q=${Uri.encodeQueryComponent(query)}',
            headers: {'Authorization': 'Bearer $token'});
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(BibleSearchResultItem.fromJson)
        .toList();
  }

  Future<List<BibleReadingPlanItem>> fetchReadingPlans() async {
    final response = await _getJson('/bible/plans');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(BibleReadingPlanItem.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchBibleHome(String? token) async {
    final response = token == null || token.isEmpty
        ? await _getJson('/bible/home')
        : await _getJson('/bible/home',
            headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchBibleChapter({
    String? token,
    required String version,
    required String book,
    required int chapter,
  }) async {
    final path = '/bible/reader?version=${Uri.encodeQueryComponent(version)}'
        '&book=${Uri.encodeQueryComponent(book)}&chapter=$chapter';
    final response = token == null || token.isEmpty
        ? await _getJson(path)
        : await _getJson(path, headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> compareBibleVerse({
    required String reference,
    required List<String> versions,
  }) async {
    final response = await _getJson(
      '/bible/compare?reference=${Uri.encodeQueryComponent(reference)}&versions=${Uri.encodeQueryComponent(versions.join(','))}',
    );
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<dynamic> joinBiblePlan({
    required String token,
    required String planId,
  }) {
    return _postJson('/bible/plans/$planId/join', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> completeBiblePlanDay({
    required String token,
    required String planId,
    required int dayNumber,
  }) {
    return _postJson('/bible/plans/$planId/progress', {'dayNumber': dayNumber},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> createStudyJournal({
    required String token,
    required String title,
    required String body,
    required String reference,
  }) {
    return _postJson(
      '/bible/journal',
      {
        'title': title,
        'body': body,
        'reference': reference,
        'entryType': 'bible_study',
        'visibility': 'private',
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> addMemoryVerse({
    required String token,
    required String reference,
    required String verseText,
  }) {
    return _postJson(
      '/bible/memory',
      {'reference': reference, 'verseText': verseText, 'status': 'learning'},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> createVerseCard({
    required String token,
    required String reference,
    required String verseText,
    required String language,
  }) {
    return _postJson(
      '/bible/verse-cards',
      {
        'reference': reference,
        'verseText': verseText,
        'style': 'sunrise-gradient',
        'language': language,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> shareBibleVerse({
    required String token,
    required String reference,
    required String verseText,
    required String channel,
  }) {
    return _postJson(
      '/bible/share',
      {'reference': reference, 'verseText': verseText, 'channel': channel},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> updateBibleSettings({
    required String token,
    required String defaultVersion,
    required String preferredLanguage,
    required int fontSize,
    required String theme,
  }) {
    return _postJson(
      '/bible/settings',
      {
        'defaultVersion': defaultVersion,
        'preferredLanguage': preferredLanguage,
        'fontSize': fontSize,
        'theme': theme,
        'verseNumbers': true,
        'audioSpeed': 1,
        'reminderTime': '07:00',
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> createGroupBibleStudy({
    required String token,
    required String title,
    required String assignment,
  }) {
    return _postJson(
      '/bible/group-studies',
      {
        'title': title,
        'scopeType': 'community',
        'currentAssignment': assignment
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> addGroupBibleStudyNote({
    required String token,
    required String studyId,
    required String reference,
    required String note,
  }) {
    return _postJson(
      '/bible/group-studies/$studyId/notes',
      {'reference': reference, 'note': note},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<BibleBookmarkItem>> fetchBibleBookmarks(String token) async {
    final response = await _getJson(
      '/bible/bookmarks',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(BibleBookmarkItem.fromJson)
        .toList();
  }

  Future<BibleBookmarkItem> createBibleBookmark({
    required String token,
    required String reference,
    required String verseText,
    required String language,
  }) async {
    final response = await _postJson(
      '/bible/bookmarks',
      {
        'reference': reference,
        'verseText': verseText,
        'language': language,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return BibleBookmarkItem.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteBibleBookmark({
    required String token,
    required String bookmarkId,
  }) async {
    await _deleteJson(
      '/bible/bookmarks/$bookmarkId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<BibleHighlightItem>> fetchBibleHighlights(String token) async {
    final response = await _getJson(
      '/bible/highlights',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(BibleHighlightItem.fromJson)
        .toList();
  }

  Future<BibleHighlightItem> createBibleHighlight({
    required String token,
    required String reference,
    required String verseText,
    required String color,
    required String note,
    required String language,
  }) async {
    final response = await _postJson(
      '/bible/highlights',
      {
        'reference': reference,
        'verseText': verseText,
        'color': color,
        'note': note,
        'language': language,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return BibleHighlightItem.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteBibleHighlight({
    required String token,
    required String highlightId,
  }) async {
    await _deleteJson(
      '/bible/highlights/$highlightId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<BibleNoteItem>> fetchBibleNotes(String token) async {
    final response = await _getJson(
      '/bible/notes',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(BibleNoteItem.fromJson)
        .toList();
  }

  Future<List<PrayerJournalItem>> fetchPrayerJournal(String token) async {
    final response = await _getJson(
      '/prayer/journal',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PrayerJournalItem.fromJson)
        .toList();
  }

  Future<PrayerJournalItem> createPrayerJournalEntry({
    required String token,
    required String title,
    required String body,
  }) async {
    final response = await _postJson(
      '/prayer/journal',
      {'title': title, 'body': body},
      headers: {'Authorization': 'Bearer $token'},
    );
    return PrayerJournalItem.fromJson(response as Map<String, dynamic>);
  }

  Future<PrayerJournalItem> answerPrayerJournalEntry({
    required String token,
    required String entryId,
    required String answer,
  }) async {
    final response = await _patchJson(
      '/prayer/journal/$entryId/answer',
      {'answer': answer},
      headers: {'Authorization': 'Bearer $token'},
    );
    return PrayerJournalItem.fromJson(response as Map<String, dynamic>);
  }

  Future<BibleNoteItem> createBibleNote({
    required String token,
    required String reference,
    required String verseText,
    required String note,
    required String language,
  }) async {
    final response = await _postJson(
      '/bible/notes',
      {
        'reference': reference,
        'verseText': verseText,
        'note': note,
        'language': language,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return BibleNoteItem.fromJson(response as Map<String, dynamic>);
  }

  Future<BibleNoteItem> updateBibleNote({
    required String token,
    required String noteId,
    String? reference,
    String? verseText,
    String? note,
    String? language,
  }) async {
    final response = await _patchJson(
      '/bible/notes/$noteId',
      {
        if (reference != null) 'reference': reference,
        if (verseText != null) 'verseText': verseText,
        if (note != null) 'note': note,
        if (language != null) 'language': language,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return BibleNoteItem.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteBibleNote({
    required String token,
    required String noteId,
  }) async {
    await _deleteJson(
      '/bible/notes/$noteId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<PaymentHistoryItem> createPaymentRecord({
    required String token,
    required String planId,
  }) async {
    final response = await _postJson(
      '/payments/history',
      {'planId': planId},
      headers: {'Authorization': 'Bearer $token'},
    );
    return PaymentHistoryItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<CourtshipProfileItem>> fetchCourtshipProfiles() async {
    final response = await _getJson('/courtship/profiles');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CourtshipProfileItem.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> fetchRelationshipHome(String token) async {
    final response = await _getJson('/relationship/home',
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveRelationshipProfile(
      String token, Map<String, dynamic> input) async {
    final response = await _putJson('/relationship/profile', input,
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> discoverRelationships(
      String token, Map<String, dynamic> filters) async {
    final response = await _postJson('/relationship/discover', filters,
        headers: {'Authorization': 'Bearer $token'});
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<dynamic> expressRelationshipInterest(
      String token, String receiverId, String note) {
    return _postJson(
        '/relationship/interests', {'receiverId': receiverId, 'note': note},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> acceptRelationshipInterest(String token, String interestId) {
    return _patchJson('/relationship/interests/$interestId/accept', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> rejectRelationshipInterest(String token, String interestId) {
    return _patchJson('/relationship/interests/$interestId/reject', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> fetchRelationshipConnection(
      String token, String connectionId) async {
    final response = await _getJson('/relationship/connections/$connectionId',
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<dynamic> updateRelationshipStage(
      String token, String connectionId, String stage) {
    return _patchJson(
        '/relationship/connections/$connectionId/stage', {'stage': stage},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> sendRelationshipMessage(
      String token, String connectionId, String body,
      {String verseReference = ''}) {
    return _postJson('/relationship/connections/$connectionId/messages',
        {'body': body, 'verseReference': verseReference},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> addRelationshipPrayer(
      String token, String connectionId, String title, String body) {
    return _postJson('/relationship/connections/$connectionId/prayers',
        {'title': title, 'body': body},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> addRelationshipBiblePlan(
      String token, String connectionId, String title, String passage) {
    return _postJson('/relationship/connections/$connectionId/bible-plans',
        {'title': title, 'passage': passage},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> addRelationshipMilestone(
      String token, String connectionId, String title, String type) {
    return _postJson('/relationship/connections/$connectionId/milestones',
        {'title': title, 'type': type},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> inviteRelationshipMentor(
      String token, String connectionId, String mentorId) {
    return _postJson('/relationship/connections/$connectionId/mentors',
        {'mentorId': mentorId},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> reportRelationshipSafety(String token,
      {String? targetUserId,
      String? relationshipId,
      String reason = 'Safety concern'}) {
    return _postJson('/relationship/safety/report', {
      'targetUserId': targetUserId,
      'relationshipId': relationshipId,
      'reason': reason
    }, headers: {
      'Authorization': 'Bearer $token'
    });
  }

  // ---- Relationship social profile (photos, prompts, stories) ----
  Future<Map<String, dynamic>> viewRelationshipProfile(String token, String userId) async {
    final response = await _getJson('/relationship/profiles/$userId',
        headers: {'Authorization': 'Bearer $token'});
    return (response as Map).cast<String, dynamic>();
  }

  Future<dynamic> addRelationshipPhoto(String token, String url, {String caption = ''}) {
    return _postJson('/relationship/profile/photos', {'url': url, 'caption': caption},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> deleteRelationshipPhoto(String token, String photoId) {
    return _deleteJson('/relationship/profile/photos/$photoId',
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> setRelationshipPrompts(String token, List<Map<String, String>> prompts) {
    return _putJson('/relationship/profile/prompts', {'prompts': prompts},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<List<Map<String, dynamic>>> fetchRelationshipStoryFeed(String token) async {
    final response = await _getJson('/relationship/stories',
        headers: {'Authorization': 'Bearer $token'});
    return (response as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchRelationshipProfileStories(String token, String userId) async {
    final response = await _getJson('/relationship/profiles/$userId/stories',
        headers: {'Authorization': 'Bearer $token'});
    return (response as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchRelationshipStoryViewers(String token) async {
    final response = await _getJson('/relationship/stories/viewers',
        headers: {'Authorization': 'Bearer $token'});
    return (response as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<dynamic> createRelationshipStory(String token, {String mediaUrl = '', String caption = ''}) {
    return _postJson('/relationship/stories', {'mediaUrl': mediaUrl, 'caption': caption},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> viewRelationshipStory(String token, String storyId) {
    return _postJson('/relationship/stories/$storyId/view', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<CourtshipProfileItem?> fetchCourtshipMe(String token) async {
    final response = await _getJson(
      '/courtship/me',
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response == null) {
      return null;
    }
    return CourtshipProfileItem.fromJson(response as Map<String, dynamic>);
  }

  Future<CourtshipProfileItem> saveCourtshipMe({
    required String token,
    required String churchName,
    required String city,
    required String bio,
    required String interests,
    required String faithStatement,
    required String ministryInvolvement,
    required String lifeGoals,
    required String marriageVision,
    required String relationshipIntent,
    required bool visible,
  }) async {
    final response = await _putJson(
      '/courtship/me',
      {
        'churchName': churchName,
        'city': city,
        'bio': bio,
        'interests': interests,
        'faithStatement': faithStatement,
        'ministryInvolvement': ministryInvolvement,
        'lifeGoals': lifeGoals,
        'marriageVision': marriageVision,
        'relationshipIntent': relationshipIntent,
        'visible': visible,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return CourtshipProfileItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<CourtshipInterestItem>> fetchCourtshipInterests(
      String token) async {
    final response = await _getJson(
      '/courtship/interests',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CourtshipInterestItem.fromJson)
        .toList();
  }

  Future<CourtshipInterestItem> createCourtshipInterest({
    required String token,
    required String receiverId,
    required String note,
  }) async {
    final response = await _postJson(
      '/courtship/interests',
      {
        'receiverId': receiverId,
        'note': note,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return CourtshipInterestItem.fromJson(response as Map<String, dynamic>);
  }

  Future<CourtshipInterestItem> updateCourtshipInterest({
    required String token,
    required String interestId,
    required String status,
  }) async {
    final response = await _patchJson(
      '/courtship/interests/$interestId',
      {'status': status},
      headers: {'Authorization': 'Bearer $token'},
    );
    return CourtshipInterestItem.fromJson(response as Map<String, dynamic>);
  }

  Future<ModuleStatusItem> fetchChatStatus() async {
    final response = await _getJson('/chat/status');
    return ModuleStatusItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<ChatMessageItem>> fetchChatMessages(
      {String room = 'general'}) async {
    final response = await _getJson('/chat/messages?room=$room');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChatMessageItem.fromJson)
        .toList();
  }

  Future<ChatMessageItem> sendChatMessage({
    required String token,
    required String body,
    String room = 'general',
  }) async {
    final response = await _postJson(
      '/chat/messages?room=$room',
      {'body': body},
      headers: {'Authorization': 'Bearer $token'},
    );
    return ChatMessageItem.fromJson(response as Map<String, dynamic>);
  }

  Future<ModuleStatusItem> fetchModerationStatus() async {
    final response = await _getJson('/moderation/status');
    return ModuleStatusItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<ReportItem>> fetchReports(String token) async {
    final response = await _getJson(
      '/moderation/reports',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ReportItem.fromJson)
        .toList();
  }

  Future<ReportItem> updateReportStatus({
    required String token,
    required String reportId,
    required String status,
  }) async {
    final response = await _patchJson(
      '/moderation/reports/$reportId',
      {'status': status},
      headers: {'Authorization': 'Bearer $token'},
    );
    return ReportItem.fromJson(response as Map<String, dynamic>);
  }

  Future<List<ChurchMembershipItem>> fetchMyChurchMemberships(
      String token) async {
    final response = await _getJson(
      '/users/me/church-memberships',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChurchMembershipItem.fromJson)
        .toList();
  }

  Future<dynamic> joinChurch({
    required String token,
    required String churchId,
  }) async {
    return _postJson(
      '/churches/$churchId/join',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> leaveChurch({
    required String token,
    required String churchId,
  }) async {
    return _deleteJson(
      '/churches/$churchId/leave',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> followChurch({
    required String token,
    required String churchId,
  }) async {
    return _postJson(
      '/churches/$churchId/follow',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> unfollowChurch({
    required String token,
    required String churchId,
  }) async {
    return _deleteJson(
      '/churches/$churchId/follow',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> createReport({
    required String token,
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    return _postJson(
      '/moderation/reports',
      {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> createPost({
    required String token,
    required String body,
    required String language,
    String postType = 'text',
    List<String> mediaUrls = const [],
    String? pollQuestion,
    List<String> pollOptions = const [],
  }) async {
    return _postJson(
      '/posts',
      {
        'body': body,
        'language': language,
        'postType': postType,
        'mediaUrls': mediaUrls,
        if (pollQuestion != null) 'pollQuestion': pollQuestion,
        if (pollOptions.isNotEmpty) 'pollOptions': pollOptions,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> updateProfile({
    required String token,
    String? fullName,
    String? language,
  }) async {
    return _patchJson(
      '/users/me',
      {
        if (fullName != null) 'fullName': fullName,
        if (language != null) 'language': language,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> fetchProfileDashboard(String token) async {
    final response = await _getJson('/profile/me',
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfileDashboard(
      String token, Map<String, dynamic> input) async {
    final response = await _patchJson('/profile/me', input,
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<dynamic> saveProfileContent(String token, Map<String, dynamic> input) {
    return _postJson('/profile/saved', input,
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> checkUsernameAvailability(
      String username) async {
    final response = await _getJson(
        '/auth/username-availability?username=${Uri.encodeQueryComponent(username)}');
    return response as Map<String, dynamic>;
  }

  Future<AuthResult> register({
    required String fullName,
    required String phoneNumber,
    required String username,
    required String password,
    required String confirmPassword,
    required String language,
  }) async {
    final response = await _postJson(
      '/auth/register',
      {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'username': username,
        'password': password,
        'confirmPassword': confirmPassword,
        'language': language,
      },
    );
    return AuthResult.fromJson(response as Map<String, dynamic>);
  }

  Future<AuthResult> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _postJson(
      '/auth/login',
      {
        'phoneNumber': phoneNumber,
        'password': password,
      },
    );
    return AuthResult.fromJson(response as Map<String, dynamic>);
  }

  Future<dynamic> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _postJson(
      '/auth/change-password',
      {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> resetPassword({
    required String phoneNumber,
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _postJson('/auth/reset-password', {
      'phoneNumber': phoneNumber,
      'otpCode': otpCode,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }

  Future<AuthResult> refresh(String refreshToken) async {
    final response =
        await _postJson('/auth/refresh', {'refreshToken': refreshToken});
    return AuthResult.fromJson(response as Map<String, dynamic>);
  }

  Future<void> logout(String token) async {
    await _postJson('/auth/logout', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<UserProfile?> me(String token) async {
    try {
      final response = await _getJson(
        '/auth/me',
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response == null) {
        return null;
      }
      return UserProfile.fromJson(response as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchPublicProfile(String userId) async {
    final response = await _getJson('/profile/$userId');
    return response as Map<String, dynamic>;
  }

  Future<List<GlobalSearchResultItem>> globalSearch(String query,
      {String? token}) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final response = await _getJson('/search?q=$encoded',
        headers: token == null ? const {} : {'Authorization': 'Bearer $token'});
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(GlobalSearchResultItem.fromJson)
        .toList();
  }

  Future<List<NotificationItem>> fetchNotifications(String token) async {
    final response = await _getJson(
      '/notifications',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList();
  }

  Future<int> fetchUnreadNotificationCount(String token) async {
    final response = await _getJson(
      '/notifications/unread-count',
      headers: {'Authorization': 'Bearer $token'},
    );
    return (response as Map<String, dynamic>)['count'] as int? ?? 0;
  }

  Future<dynamic> markNotificationRead({
    required String token,
    required String notificationId,
  }) {
    return _patchJson(
      '/notifications/$notificationId/read',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> markAllNotificationsRead(String token) {
    return _patchJson(
      '/notifications/read-all',
      const {},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> fetchJourneyDashboard(String token) async {
    final response = await _getJson('/journey/dashboard',
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<dynamic> requestOtp(String phoneNumber) {
    return _postJson('/journey/otp/request', {'phoneNumber': phoneNumber});
  }

  Future<dynamic> verifyOtp(String phoneNumber, String code) {
    return _postJson(
        '/journey/otp/verify', {'phoneNumber': phoneNumber, 'code': code});
  }

  Future<Map<String, dynamic>> completeJourneyOnboarding({
    required String token,
    required Map<String, dynamic> profile,
  }) async {
    final response = await _postJson('/journey/onboarding', profile,
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> enrollReadingPlan(
      String token, String planId) async {
    final response = await _postJson('/journey/plans/$planId/enroll', const {},
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkinReadingPlan(
      String token, String planId) async {
    final response = await _postJson('/journey/plans/$planId/checkin', const {},
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> enrollCourse(
      String token, String courseId) async {
    final response = await _postJson(
        '/journey/courses/$courseId/enroll', const {},
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> progressCourse(
      String token, String courseId) async {
    final response = await _postJson(
        '/journey/courses/$courseId/progress', const {},
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchMarketplace() async {
    final response = await _getJson('/journey/marketplace');
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<MarketplaceListingItem>> fetchMarketplaceListings() async {
    final response = await _getJson('/journey/marketplace');
    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MarketplaceListingItem.fromJson)
        .toList();
  }

  Future<MarketplaceListingItem> createMarketplaceListing({
    required String token,
    required String title,
    required String category,
    required String description,
    required int priceCents,
    required String condition,
    required String location,
    required String phoneNumber,
    required String imageUrl,
  }) async {
    final response = await _postJson(
      '/journey/marketplace',
      {
        'title': title,
        'category': category,
        'description': description,
        'priceCents': priceCents,
        'condition': condition,
        'location': location,
        'phoneNumber': phoneNumber,
        'imageUrl': imageUrl,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
    return MarketplaceListingItem.fromJson(response as Map<String, dynamic>);
  }

  Future<MarketplaceOrderItem> orderMarketplaceListing(
      String token, String listingId) async {
    final response = await _postJson(
        '/journey/marketplace/$listingId/order', const {},
        headers: {'Authorization': 'Bearer $token'});
    return MarketplaceOrderItem.fromJson(response as Map<String, dynamic>);
  }

  Future<dynamic> orderMarketplaceItem(String token, String listingId) {
    return _postJson('/journey/marketplace/$listingId/order', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> toggleSavedPost(
      String token, String postId) async {
    final response = await _postJson('/journey/posts/$postId/save', const {},
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<dynamic> markPrayerPrayed(String token, String prayerId) {
    return _postJson('/journey/prayers/$prayerId/prayed', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> replyToStory(String token, String storyId, String body) {
    return _postJson('/journey/stories/$storyId/replies', {'body': body},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> sendFriendRequest(String token, String userId) {
    return _postJson('/journey/friends/$userId/request', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> updateFriendRequest(
      String token, String requestId, String status) {
    return _patchJson(
        '/journey/friends/requests/$requestId', {'status': status},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> withdrawFriendRequest(String token, String requestId) {
    return _deleteJson('/journey/friends/requests/$requestId',
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> _getJson(String path,
      {Map<String, String> headers = const {}}) async {
    return _requestJson('GET', path, headers: headers);
  }

  Future<Map<String, dynamic>> fetchConnectedLife(String token) async {
    final response = await _getJson('/connected-life/dashboard',
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchCommunityHome(String token) async {
    final response = await _getJson('/community/home',
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<dynamic> createCommunityGroup(
      String token, Map<String, dynamic> input) {
    return _postJson('/community/groups', input,
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> joinCommunityGroup(String token, String groupId) {
    return _postJson('/community/groups/$groupId/join', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> createCommunityDiscussion(
      String token, Map<String, dynamic> input) {
    return _postJson('/community/discussions', input,
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> replyCommunityDiscussion(
      String token, String discussionId, String body) {
    return _postJson(
        '/community/discussions/$discussionId/replies', {'body': body},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> upvoteCommunityDiscussion(String token, String discussionId) {
    return _postJson('/community/discussions/$discussionId/upvote', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> saveCommunityDiscussion(String token, String discussionId) {
    return _postJson('/community/discussions/$discussionId/save', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> requestPrayerPartner(
      String token, Map<String, dynamic> input) {
    return _postJson('/community/prayer-partners', input,
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> matchPrayerPartner(String token, String requestId) {
    return _postJson('/community/prayer-partners/$requestId/match', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> registerCommunityEvent(String token, String eventId) {
    return _postJson('/community/events/$eventId/register', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> fetchGroupActivity(String groupId) async {
    final response = await _getJson('/connected-life/groups/$groupId/activity');
    return response as Map<String, dynamic>;
  }

  Future<dynamic> createGroupPost(String token, String groupId, String body) {
    return _postJson('/connected-life/groups/$groupId/posts', {'body': body},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> createGroupResource(
      String token, String groupId, String title, String url) {
    return _postJson('/connected-life/groups/$groupId/resources',
        {'title': title, 'resourceUrl': url, 'resourceType': 'link'},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> startConversation(
      String token, String otherUserId,
      {String kind = 'direct'}) async {
    final response = await _postJson('/connected-life/conversations',
        {'otherUserId': otherUserId, 'kind': kind},
        headers: {'Authorization': 'Bearer $token'});
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> openScopedConversation(
    String token, {
    required String scopeType,
    required String scopeId,
    String? otherUserId,
  }) async {
    final response = await _postJson('/connected-life/conversations/scope', {
      'scopeType': scopeType,
      'scopeId': scopeId,
      if (otherUserId != null && otherUserId.isNotEmpty)
        'otherUserId': otherUserId,
    }, headers: {
      'Authorization': 'Bearer $token'
    });
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchConversationMessages(
    String token,
    String conversationId, {
    int limit = 50,
    String? before,
    String? after,
  }) async {
    final params = <String>['limit=$limit'];
    if (before != null && before.isNotEmpty) params.add('before=$before');
    if (after != null && after.isNotEmpty) params.add('after=$after');
    final response = await _getJson(
        '/connected-life/conversations/$conversationId/messages?${params.join('&')}',
        headers: {'Authorization': 'Bearer $token'});
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<dynamic> sendDirectMessage(
      String token, String conversationId, String body,
      {String attachmentUrl = '', String attachmentType = ''}) {
    return _postJson('/connected-life/conversations/$conversationId/messages', {
      'body': body,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType
    }, headers: {
      'Authorization': 'Bearer $token'
    });
  }

  Future<dynamic> markConversationRead(String token, String conversationId,
      {String? messageId}) {
    return _putJson('/connected-life/conversations/$conversationId/read', {
      if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
    }, headers: {
      'Authorization': 'Bearer $token'
    });
  }

  Future<dynamic> markConversationUnread(String token, String conversationId,
      {String? messageId}) {
    return _putJson('/connected-life/conversations/$conversationId/unread', {
      if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
    }, headers: {
      'Authorization': 'Bearer $token'
    });
  }

  Future<List<Map<String, dynamic>>> fetchConversationMembers(
      String token, String conversationId) async {
    final response = await _getJson(
        '/connected-life/conversations/$conversationId/members',
        headers: {'Authorization': 'Bearer $token'});
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<dynamic> editConversationMessage(
      String token, String conversationId, String messageId, String body) {
    return _patchJson(
      '/connected-life/conversations/$conversationId/messages/$messageId',
      {'body': body},
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<dynamic> deleteConversationMessage(
      String token, String conversationId, String messageId) {
    return _deleteJson(
      '/connected-life/conversations/$conversationId/messages/$messageId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<Map<String, dynamic>>> fetchIceServers(String token) async {
    final response = await _getJson('/calls/ice-servers',
        headers: {'Authorization': 'Bearer $token'});
    final servers = (response as Map<String, dynamic>)['iceServers'];
    if (servers is List) {
      return servers.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return const [];
  }

  Future<dynamic> enrollChallenge(String token, String challengeId) {
    return _postJson('/connected-life/challenges/$challengeId/enroll', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> checkinChallenge(String token, String challengeId) {
    return _postJson(
        '/connected-life/challenges/$challengeId/checkin', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> joinCampaign(String token, String campaignId) {
    return _postJson('/connected-life/campaigns/$campaignId/join', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> submitMedia(String token, Map<String, dynamic> input) {
    return _postJson('/connected-life/media', input,
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> likeMediaSubmission(String token, String submissionId) {
    return _postJson('/connected-life/media/$submissionId/like', const {},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> recordDonation(String token, String fundId, double amount) {
    return _postJson('/connected-life/funds/$fundId/donate', {'amount': amount},
        headers: {'Authorization': 'Bearer $token'});
  }

  Future<dynamic> updateTeenProfile(String token,
      {required bool isTeen,
      required String guardianName,
      required bool guardianApproved}) {
    return _putJson('/connected-life/teen-profile', {
      'isTeen': isTeen,
      'guardianName': guardianName,
      'guardianApproved': guardianApproved,
    }, headers: {
      'Authorization': 'Bearer $token'
    });
  }

  Future<dynamic> _postJson(String path, Map<String, dynamic> body,
      {Map<String, String> headers = const {}}) async {
    return _requestJson('POST', path, body: body, headers: headers);
  }

  Future<dynamic> _deleteJson(String path,
      {Map<String, String> headers = const {}}) async {
    return _requestJson('DELETE', path, headers: headers);
  }

  Future<dynamic> _putJson(String path, Map<String, dynamic> body,
      {Map<String, String> headers = const {}}) async {
    return _requestJson('PUT', path, body: body, headers: headers);
  }

  Future<dynamic> _patchJson(String path, Map<String, dynamic> body,
      {Map<String, String> headers = const {}}) async {
    return _requestJson('PATCH', path, body: body, headers: headers);
  }

  Future<dynamic> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json; charset=utf-8',
        ...headers,
      });
    if (body != null) request.bodyBytes = utf8.encode(jsonEncode(body));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final responseBody = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
          '$method $path: ${_errorMessage(responseBody, response.statusCode)}');
    }
    if (responseBody.trim().isEmpty) {
      return null;
    }
    return jsonDecode(responseBody);
  }

  String _errorMessage(String body, int statusCode) {
    if (body.trim().isEmpty) return 'Request failed with $statusCode';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String) return message;
        if (message is List) return message.join(', ');
      }
    } catch (_) {
      // Preserve non-JSON server responses for diagnostics.
    }
    return body;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
