-module(userops).
-compile(export_all).
-compile(nowarn_export_all). 
-define(MAX_FEED_LENGTH, 10). 


add_karma_to_user(Username, AddKarma) -> 
    Ans = ets:lookup(user_info, Username), 
    {User, Karma, A, B, C, D} = lists:nth(1, Ans),
    ets:insert(user_info, {User, Karma + AddKarma, A, B, C, D}). 


add_post_id_to_feed(Username, NewPostID) -> 
    Ans = ets:lookup(user_info, Username),
    case Ans of 
        {Username, Karma, Feed, ChatID, CommentID, PostID}->
            case length(Feed) >  ?MAX_FEED_LENGTH of
                true -> 
                    [Head | _] = Feed, 
                    NewFeed = Head; 
                false -> 
                    NewFeed = Feed
            end, 
            FinFeed = [NewPostID | NewFeed], 
            ets:insert(user_info, {Username, Karma, FinFeed, ChatID, CommentID, PostID}), 
            true; 
        false -> 
            false
    end. 




add_subreddit_to_user(Username, Subreddit) -> 
    Ans = ets:member(user_info, Username),
    case Ans of 
        true->
            SubRecord = ets:match_object(subscriptions, {'_', Subreddit, Username}), 
            case SubRecord of 
                [] -> 
                    SubscriptionID = server:get_new_id(), 
                    ets:insert(subscriptions, {SubscriptionID, Subreddit, Username}), 
                    true; 
                _ -> 
                    % Cannot subcribe to a subreddit twice
                    false
            end;  
        false -> 
            false
    end. 


remove_subreddit_from_user(Username, Subreddit) -> 
    Ans = ets:member(user_info, Username),
    case Ans of 
        true -> 
            ets:delete_object(subscriptions, {'_', Subreddit, Username}),
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


