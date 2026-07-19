part of '../module_pages.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.language,
    required this.item,
    required this.apiClient,
    required this.session,
    required this.onReport,
    required this.onDataChanged,
  });

  final AppLanguage language;
  final FeedItem item;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<void> Function() onReport;
  final Future<void> Function() onDataChanged;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  int? _selectedPollOption;
  late FeedItem _post;
  late Future<List<PostCommentItem>> _commentsFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _post = widget.item;
    _commentsFuture = _loadComments();
  }

  @override
  void didUpdateWidget(covariant PostDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.session?.token != widget.session?.token) {
      _post = widget.item;
      _commentsFuture = _loadComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _replyControllerFor(String commentId) {
    return _replyControllers.putIfAbsent(
        commentId, () => TextEditingController());
  }

  Future<List<PostCommentItem>> _loadComments() async {
    return widget.apiClient
        .fetchPostComments(_post.id, token: widget.session?.token);
  }

  Future<void> _refreshComments() async {
    final future = _loadComments();
    setState(() {
      _commentsFuture = future;
    });
    await future;
  }

  Future<void> _runAction(Future<void> Function() action,
      {String? successMessage}) async {
    setState(() {
      _busy = true;
      _status = AppStrings.of(widget.language, 'working');
    });
    try {
      await action();
      await widget.onDataChanged();
      await _refreshComments();
      if (mounted && successMessage != null) {
        setState(() => _status = successMessage);
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _status = error.toString().replaceFirst('HttpException: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleLike() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }
    final liked = _post.likedByMe;
    await _runAction(() async {
      if (liked) {
        await widget.apiClient.unlikePost(token: token, postId: _post.id);
      } else {
        await widget.apiClient.likePost(token: token, postId: _post.id);
      }
      setState(() {
        _post = _post.copyWith(
          likedByMe: !liked,
          likeCount: liked
              ? (_post.likeCount > 0 ? _post.likeCount - 1 : 0)
              : _post.likeCount + 1,
        );
      });
    },
        successMessage: liked
            ? AppStrings.of(widget.language, 'unlike_success')
            : AppStrings.of(widget.language, 'like_success'));
  }

  Future<void> _share() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }
    await _runAction(() async {
      await widget.apiClient.sharePost(token: token, postId: _post.id);
      setState(() {
        _post = _post.copyWith(shareCount: _post.shareCount + 1);
      });
    }, successMessage: AppStrings.of(widget.language, 'share_success'));
  }

  Future<void> _react(String reaction) async {
    final token = widget.session?.token;
    if (token == null) {
      promptSignIn(context, widget.language);
      return;
    }
    await _runAction(() async {
      await widget.apiClient.reactToPost(token, _post.id, reaction);
    }, successMessage: 'Reaction sent.');
  }

  Future<void> _repost() async {
    final token = widget.session?.token;
    if (token == null) {
      promptSignIn(context, widget.language);
      return;
    }
    await _runAction(() async {
      await widget.apiClient.repostPost(token, _post.id,
          'Shared with my community: ${_post.body}', widget.language.code);
    }, successMessage: 'Reposted to your community.');
  }

  Future<void> _comment() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }
    final body = _commentController.text.trim();
    if (body.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'message_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient
          .createPostComment(token: token, postId: _post.id, body: body);
      _commentController.clear();
      setState(() {
        _post = _post.copyWith(commentCount: _post.commentCount + 1);
      });
    }, successMessage: AppStrings.of(widget.language, 'comment_success'));
  }

  Future<void> _replyToComment(PostCommentItem comment) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }
    final controller = _replyControllerFor(comment.id);
    final body = controller.text.trim();
    if (body.isEmpty) {
      setState(
          () => _status = AppStrings.of(widget.language, 'message_required'));
      return;
    }
    await _runAction(() async {
      await widget.apiClient.replyToComment(token, _post.id, comment.id, body);
      controller.clear();
    }, successMessage: 'Reply posted.');
  }

  Future<void> _votePoll(int optionIndex) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }
    await _runAction(() async {
      await widget.apiClient.votePostPoll(token, _post.id, optionIndex);
      setState(() => _selectedPollOption = optionIndex);
    }, successMessage: 'Poll vote saved.');
  }

  Future<void> _followAuthor() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }
    if (_post.authorId.isEmpty || widget.session?.user.id == _post.authorId) {
      return;
    }
    await _runAction(
        () => widget.apiClient.followUser(token: token, userId: _post.authorId),
        successMessage: AppStrings.of(widget.language, 'follow_success'));
  }

  Widget _socialStat(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(
          title: Text(AppStrings.of(language, 'post_details'),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<List<PostCommentItem>>(
        future: _commentsFuture,
        builder: (context, snapshot) {
          final comments = snapshot.data ?? const <PostCommentItem>[];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          child: Icon(Icons.auto_awesome_rounded,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_post.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(
                                _post.createdAt.isEmpty
                                    ? _post.language.toUpperCase()
                                    : '${_shortDate(_post.createdAt)} • ${_post.language.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (_post.language == 'am')
                          const Icon(Icons.translate_rounded),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(_post.body,
                        style: Theme.of(context).textTheme.bodyLarge),
                    if (_post.hashtags.isNotEmpty ||
                        _post.mentions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in _post.hashtags)
                            Chip(
                                label: Text(tag,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          for (final mention in _post.mentions)
                            Chip(
                                label: Text(mention,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                    if (_post.postType == 'poll' &&
                        _post.pollOptions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        _post.pollQuestion.isEmpty
                            ? 'Poll'
                            : _post.pollQuestion,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var index = 0;
                              index < _post.pollOptions.length;
                              index++)
                            ChoiceChip(
                              label: Text(_post.pollOptions[index]),
                              selected: _selectedPollOption == index,
                              onSelected:
                                  _busy ? null : (_) => _votePoll(index),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _socialStat(
                            Icons.favorite_rounded, '${_post.likeCount}'),
                        _socialStat(Icons.mode_comment_outlined,
                            '${_post.commentCount}'),
                        _socialStat(
                            Icons.ios_share_rounded, '${_post.shareCount}'),
                        _socialStat(
                            Icons.verified_rounded,
                            _post.likedByMe
                                ? AppStrings.of(language, 'liked')
                                : AppStrings.of(language, 'not_liked')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final reaction in const [
                            "🙏",
                            "❤️",
                            "🔥",
                            "🙌",
                            "💡"
                          ])
                            Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                    label: Text(reaction,
                                        style: const TextStyle(fontSize: 20)),
                                    onPressed:
                                        _busy ? null : () => _react(reaction))),
                        ])),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _toggleLike,
                          icon: Icon(_post.likedByMe
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded),
                          label: Text(_post.likedByMe
                              ? AppStrings.of(language, 'unlike_post')
                              : AppStrings.of(language, 'like_post')),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _share,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: Text(AppStrings.of(language, 'share_post')),
                        ),
                        FilledButton.tonalIcon(
                            onPressed: _busy ? null : _repost,
                            icon: const Icon(Icons.repeat_rounded),
                            label: const Text("Repost")),
                        if (_post.authorId.isNotEmpty &&
                            widget.session?.user.id != _post.authorId)
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _followAuthor,
                            icon: const Icon(Icons.person_add_alt_rounded),
                            label:
                                Text(AppStrings.of(language, 'follow_author')),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await widget.onReport();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          icon: const Icon(Icons.report_rounded),
                          label: Text(AppStrings.of(language, 'report_post')),
                        ),
                      ],
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_status,
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: AppStrings.of(language, 'write_comment'),
                children: [
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                        labelText: AppStrings.of(language, 'message_body')),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _comment,
                    child: Text(AppStrings.of(language, 'comment_post')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title:
                    '${AppStrings.of(language, 'post_comments')} (${comments.length})',
                children: snapshot.connectionState == ConnectionState.waiting &&
                        comments.isEmpty
                    ? const [
                        Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: CircularProgressIndicator()))
                      ]
                    : comments.isEmpty
                        ? [Text(AppStrings.of(language, 'no_comments_yet'))]
                        : [
                            for (final comment in comments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _MiniCard(
                                          icon: Icons.forum_rounded,
                                          title: comment.authorName,
                                          body: comment.body,
                                          trailing: Text(
                                            comment.createdAt.isEmpty
                                                ? ''
                                                : _shortDate(comment.createdAt),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          controller:
                                              _replyControllerFor(comment.id),
                                          decoration: const InputDecoration(
                                            labelText: 'Reply',
                                            isDense: true,
                                          ),
                                          minLines: 1,
                                          maxLines: 2,
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: FilledButton.tonalIcon(
                                            onPressed: _busy
                                                ? null
                                                : () =>
                                                    _replyToComment(comment),
                                            icon:
                                                const Icon(Icons.reply_rounded),
                                            label: const Text('Reply'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late Future<List<ChatMessageItem>> _messagesFuture;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _messagesFuture = _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<List<ChatMessageItem>> _load() async {
    return widget.apiClient.fetchChatMessages();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _messagesFuture = future;
    });
    await future;
  }

  Future<void> _send() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }
    final body = _messageController.text.trim();
    if (body.isEmpty) {
      setState(() {
        _status = AppStrings.of(widget.language, 'message_required');
      });
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.sendChatMessage(token: token, body: body);
      _messageController.clear();
      await _refresh();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = AppStrings.of(widget.language, 'message_sent');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'chat'))),
      body: FutureBuilder<ModuleStatusItem>(
        future: widget.apiClient.fetchChatStatus(),
        builder: (context, statusSnapshot) {
          return FutureBuilder<List<ChatMessageItem>>(
            future: _messagesFuture,
            builder: (context, messagesSnapshot) {
              final messages =
                  messagesSnapshot.data ?? const <ChatMessageItem>[];
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _SectionCard(
                      title: AppStrings.of(language, 'chat'),
                      children: [
                        Text(AppStrings.of(language, 'chat_body'),
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        Text(
                            '${AppStrings.of(language, 'chat_status')}: ${statusSnapshot.data == null ? '...' : '${statusSnapshot.data!.module} • ${statusSnapshot.data!.ready ? AppStrings.of(language, 'ready') : AppStrings.of(language, 'not_ready')}'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        Text(
                            '${AppStrings.of(language, 'chat_room')}: general'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: AppStrings.of(language, 'send_message'),
                      children: [
                        TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                              labelText:
                                  AppStrings.of(language, 'message_body')),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _send,
                          child: Text(AppStrings.of(language, 'send_message')),
                        ),
                        if (_status.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_status,
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: AppStrings.of(language, 'messages'),
                      children: messages.isEmpty
                          ? [Text(AppStrings.of(language, 'no_messages_yet'))]
                          : [
                              for (final message in messages)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ListTileRow(
                                    icon: Icons.chat_bubble_rounded,
                                    title: message.authorFullName,
                                    subtitle:
                                        '${message.body}\n${_shortDate(message.createdAt)}',
                                  ),
                                ),
                            ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ReportingScreen extends StatefulWidget {
  const ReportingScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session,
      required this.onDataChanged});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;
  final Future<void> Function() onDataChanged;

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  final TextEditingController _targetTypeController =
      TextEditingController(text: 'post');
  final TextEditingController _targetIdController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _busy = false;
  String _status = '';
  late Future<List<ReportItem>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = Future.value(const <ReportItem>[]);
  }

  @override
  void dispose() {
    _targetTypeController.dispose();
    _targetIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _refreshReports() async {
    final future = Future.value(const <ReportItem>[]);
    setState(() {
      _reportsFuture = future;
    });
    await future;
  }

  Future<void> _submit() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.createReport(
        token: token,
        targetType: _targetTypeController.text,
        targetId: _targetIdController.text,
        reason: _reasonController.text,
      );
      await _refreshReports();
      await widget.onDataChanged();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = AppStrings.of(widget.language, 'report_success');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _setStatus(String reportId, String status) async {
    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.updateReportStatus(
          token: widget.session?.token ?? '',
          reportId: reportId,
          status: status);
      await _refreshReports();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status == 'resolved'
            ? AppStrings.of(widget.language, 'report_resolved')
            : status == 'closed'
                ? AppStrings.of(widget.language, 'report_closed')
                : AppStrings.of(widget.language, 'report_open');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'reporting'))),
      body: FutureBuilder<ModuleStatusItem>(
        future: widget.apiClient.fetchModerationStatus(),
        builder: (context, statusSnapshot) {
          return FutureBuilder<List<ReportItem>>(
            future: _reportsFuture,
            builder: (context, reportsSnapshot) {
              final reports = reportsSnapshot.data ?? const <ReportItem>[];
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _SectionCard(
                    title: AppStrings.of(language, 'report_content'),
                    children: [
                      TextField(
                        controller: _targetTypeController,
                        decoration: InputDecoration(
                            labelText: AppStrings.of(language, 'target_type')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _targetIdController,
                        decoration: InputDecoration(
                            labelText: AppStrings.of(language, 'target_id')),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reasonController,
                        decoration: InputDecoration(
                            labelText: AppStrings.of(language, 'reason')),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(AppStrings.of(language, 'submit_report')),
                      ),
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_status,
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: AppStrings.of(language, 'safety_first'),
                    children: [
                      Text(AppStrings.of(language, 'safety_body'),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Text(
                          '${AppStrings.of(language, 'moderation_status')}: ${statusSnapshot.data == null ? '...' : '${statusSnapshot.data!.module} • ${statusSnapshot.data!.ready ? AppStrings.of(language, 'ready') : AppStrings.of(language, 'not_ready')}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: AppStrings.of(language, 'report_details'),
                    children: reports.isEmpty
                        ? [Text(AppStrings.of(language, 'no_request_yet'))]
                        : [
                            for (final report in reports)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${report.targetType} • ${report.targetId}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        const SizedBox(height: 8),
                                        Text(
                                            '${report.status} • ${report.reason}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _setStatus(
                                                      report.id, 'open'),
                                              child: Text(AppStrings.of(
                                                  language, 'report_open')),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _setStatus(
                                                      report.id, 'resolved'),
                                              child: Text(AppStrings.of(
                                                  language, 'resolve_report')),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _setStatus(
                                                      report.id, 'closed'),
                                              child: Text(AppStrings.of(
                                                  language, 'close_report')),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class PrayerWallScreen extends StatefulWidget {
  const PrayerWallScreen(
      {super.key,
      required this.language,
      required this.apiClient,
      required this.session});

  final AppLanguage language;
  final ApiClient apiClient;
  final AuthResult? session;

  @override
  State<PrayerWallScreen> createState() => _PrayerWallScreenState();
}

class _PrayerWallScreenState extends State<PrayerWallScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  late Future<List<PrayerRequestItem>> _requestsFuture;
  bool _busy = false;
  bool _anonymous = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _requestsFuture = widget.apiClient.fetchPrayerRequests(token: widget.session?.token);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.apiClient.fetchPrayerRequests(token: widget.session?.token);
    setState(() {
      _requestsFuture = future;
    });
    await future;
  }

  Future<void> _share() async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await widget.apiClient.createPrayerRequest(
        token: token,
        title: _titleController.text,
        body: _bodyController.text,
        anonymous: _anonymous,
      );
      _titleController.clear();
      _bodyController.clear();
      await _refresh();
      if (!mounted) return;
      setState(() {
        _status = AppStrings.of(widget.language, 'prayer_requested');
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = error.toString().replaceFirst('HttpException: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _prayed(PrayerRequestItem request) async {
    final token = widget.session?.token;
    if (token == null || token.isEmpty) {
      promptSignIn(context, widget.language);
      return;
    }
    await widget.apiClient.markPrayerPrayed(token, request.id);
    if (!mounted) return;
    setState(() => _status = 'Your prayer commitment was recorded.');
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.of(language, 'prayer_wall'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(
              title: AppStrings.of(language, 'prayer_wall'),
              subtitle: AppStrings.of(language, 'prayer'),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'share_prayer'),
              children: [
                TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                        labelText: AppStrings.of(language, 'prayer_title'))),
                const SizedBox(height: 12),
                TextField(
                    controller: _bodyController,
                    decoration: InputDecoration(
                        labelText: AppStrings.of(language, 'prayer_body')),
                    maxLines: 4),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _anonymous,
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _anonymous = value ?? false;
                          });
                        },
                  title: Text(AppStrings.of(language, 'anonymous_prayer')),
                  subtitle:
                      Text(AppStrings.of(language, 'anonymous_prayer_hint')),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                        onPressed: _busy ? null : _share,
                        child: Text(AppStrings.of(language, 'share_prayer'))),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PrayerChainsScreen(
                                language: language,
                                apiClient: widget.apiClient,
                                session: widget.session),
                          ),
                        );
                      },
                      child:
                          Text(AppStrings.of(language, 'open_prayer_chains')),
                    ),
                  ],
                ),
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: AppStrings.of(language, 'prayer_requests'),
              children: [
                FutureBuilder<List<PrayerRequestItem>>(
                  future: _requestsFuture,
                  builder: (context, snapshot) {
                    final requests =
                        snapshot.data ?? const <PrayerRequestItem>[];
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        requests.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (requests.isEmpty) {
                      return Text(AppStrings.of(language, 'no_prayer_requests'),
                          maxLines: 3, overflow: TextOverflow.ellipsis);
                    }
                    return Column(
                      children: [
                        for (final request in requests)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ListTileRow(
                              icon: request.anonymous
                                  ? Icons.lock_rounded
                                  : Icons.volunteer_activism_rounded,
                              title: request.title,
                              subtitle:
                                  '${request.requesterName} • ${request.status} • ${request.body} • Tap to mark I prayed',
                              onTap: _busy ? null : () => _prayed(request),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyDateTime(String raw) => friendlyDateTime(raw);
