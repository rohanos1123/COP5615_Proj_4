-module(userops).
-compile(export_all).
-compile(nowarn_export_all). 


add_karma_to_user(Username, AddKarma) -> 
    Ans = ets:lookup(user_info, Username), 
    {User, Karma, A, B, C, D} = lists:nth(1, Ans),
    ets:insert(user_info, {User, Karma + AddKarma, A, B, C, D}). 


add_subreddit_to_user(Username, NewSubreddit) -> 
    Ans = ets:lookup(user_info, Username),
    case Ans of 
        {User, Karma, SubredditIDs, MessageIDs, CommentIDs, PostsIDs} -> 
            ets:insert(user_info,  {User, Karma, [NewSubreddit | SubredditIDs], MessageIDs, CommentIDs, PostsIDs}), 
            true; 
        _ -> 
            false
    end. 


remove_subreddit_from_user(Username, RemoveSubreddit) -> 
    Ans = ets:lookup(user_info, Username),
    case Ans of 
        {User, Karma, SubredditIDs, MessageIDs, CommentIDs, PostsIDs} -> 
            FilteredList = lists:filter(fun(X) -> X =/= RemoveSubreddit end, SubredditIDs), 
            ets:insert(user_info, {User, Karma, FilteredList, MessageIDs, CommentIDs, PostsIDs}), 
            true; 
        _ -> 
            false
    end. 


add_written_posts(Username, NewPostID) -> 
    Ans = ets:lookup(user_info, Username),
    case Ans of 
        {User, Karma, SubredditIDs, MessageIDs, CommentIDs, PostsIDs} -> 
            ets:insert(user_info,  {User, Karma, SubredditIDs, MessageIDs, CommentIDs, [NewPostID | PostsIDs]}), 
            true; 
        _ -> 
            false
    end. 


add_written_comments(Username, NewCommentID) -> 
       Ans = ets:lookup(user_info, Username),
    case Ans of 
        {User, Karma, SubredditIDs, MessageIDs, CommentIDs, PostsIDs} -> 
            ets:insert(user_info,  {User, Karma, SubredditIDs, MessageIDs, [NewCommentID | CommentIDs], PostsIDs}), 
            true; 
        _ -> 
            false
    end. 


