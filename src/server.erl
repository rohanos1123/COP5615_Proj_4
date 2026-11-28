-module(server).
-compile(export_all).
-compile(nowarn_export_all). 

% user_auth: {Username, Password}
% user_info: {Username, Karma, Feed, ChatIDs, CommentIDs, PostsIDs}
% subreddits: {SubredditName, Description, Owner, Members, CreationDate}
% posts: {PostID, Subreddit, Owner, Title, Content, Likes, Dislikes, CreationDate}
% likes: {LikeID, ObjID, Subreddit, Mode}
% Comments: {CommentID, Owner, ParentID, Content, Likes, Dislike, CreateionDate} (For replies and top-level comments)
% Sessions: {SessionID, Username}
% direct_msg: {MsgID, ChatID, Sender, Recipient, Content, CreationDate}
% subscriptions : {SubcriptionID, SubredditName, Username}

% Note on Comments: If isReply is true, then the ObjectID refers to a comment, otherwise ObjectID refers to a post
% comments: {CommentID, Owner, Content, Likes, isReply, ObjectID}

get_new_id() -> 
    erlang:unique_integer([positive]). 

get_current_date() -> 
    calendar:local_time().  

% returns ObjType 
get_type(ObjectID) -> 
    case lists:prefix("ps_", ObjectID) of 
        true -> posts;
        false -> comments
    end. 


register_new_user(Username, Password) -> 
    Ans = ets:lookup(user_auth, Username), 
    case length(Ans) of 
        0 -> 
            ets:insert(user_auth, {Username, Password}), 
            ets:insert(user_info, {Username, 0, [], [], [], []}), 
            true; 
        _ -> 
            false
    end. 
   
    
% Verify the integrity of the user, TODO: return a session key 
authenticate_user(UserAttempt, PassAttempt) ->
    Res = ets:lookup(user_auth, UserAttempt),
    case length(Res) of
        1 -> 
            {_, Password} = lists:nth(1, Res), 
            if 
                Password == PassAttempt ->
                    InSession = ets:match_object(session, {'_', UserAttempt}), 
                    case InSession of 
                        [] -> 
                            SessionID = get_new_id(), 
                            ets:insert(session, {SessionID, UserAttempt}), 
                            {true, SessionID}; 
                        _ -> 
                            {false, -1}
                    end;
                true ->
                    {false, -1}
            end;
        _ -> 
            {false, -1}
    end.


% User Logout, removes the Session from the 
logout_user(SessionToken) -> 
    Res = ets:lookup(session, {SessionToken, '_'}),
    case Res of 
        [{SessionToken, _}] -> 
            ets:delete(session, SessionToken),
            true;
        _ -> 
            false
    end.  


% Get user
get_username(SessionToken) -> 
    Res = ets:lookup(session, SessionToken), 
    case Res of 
        [{SessionToken, Username}] -> 
            Username; 
        _ -> 
            false 
    end. 

% Create subreddit: 
create_subreddit(Username, SubredditName, SubredditDescription) -> 
    Ans = ets:lookup(subreddits, SubredditName), 
    case length(Ans) of 
        0 -> 
            ets:insert(subreddits, {SubredditName, SubredditDescription, Username, get_current_date()}), 
            userops:add_karma_to_user(Username, 10), 
            userops:add_subreddit_to_user(Username, SubredditName),
            true; 
        _ -> 
            false
    end. 


% Create Posts: 
update_feeds(SubredditName, PostID) ->  
    Followers = ets:lookup(subscriptions, SubredditName), 
    lists:foreach(
        fun({_, Username}) -> 
            userops:add_post_id_to_feed(Username, PostID)
        end, Followers). 


create_post(Username, SubredditName, PostTitle, Content) -> 
    Ans = ets:lookup(subreddits, SubredditName), 
    case length(Ans) of 
        0 -> 
            false; 
        _ -> 
            NewPostID = "ps_" ++ integer_to_list(get_new_id()), 
            ets:insert(posts, {NewPostID, SubredditName, Username, PostTitle, Content, 0, 0, get_current_date()}), 
            userops:add_karma_to_user(Username, 5), 
            userops:add_written_posts(Username, NewPostID), 
            update_feeds(SubredditName, NewPostID), 
            true
    end. 


% Todo add check to 
create_comment(Username, ParentID, Content) ->
    NewCommentID = "cm_" ++ integer_to_list(get_new_id()), 
    ets:insert(comments, {NewCommentID, Username, ParentID,  Content, 0, 0, get_current_date()}), 
    userops:add_written_comments(Username, NewCommentID), 
    userops:add_karma_to_user(Username, 2), 
    true. 

% Comments: {CommentID, Owner, ParentID, Content, Likes, Dislike, CreateionDate}

% Mode can be Like or Dislike
edit_post_likes(posts, ObjID, Mode, Username) -> 
    Search = ets:lookup(posts, ObjID), 
    case Search of 
        [{ObjID, Subreddit, Owner, Title, Content, Likes, Dislikes, CreationDate}] -> 
            case Mode of 
                upvote -> 
                    % Check if user has liked post or not
                    Res = ets:match_object(likes, {'_', ObjID, Username, '_'}), 
                    case Res of 
                        [{LikeID, ObjectID, Username, Mode}] -> 
                            case Mode of 
                                upvote -> 
                                    % Cannot upvote an item twice
                                    false; 
                                downvote ->
                                    ets:insert(likes, {LikeID, ObjID, Username, upvote}), 
                                    ets:insert(posts, {ObjID, Subreddit, Owner, Title, Content, Likes + 1, Dislikes - 1, CreationDate}), 
                                    true
                            end; 
                        _ -> 
                            ets:insert(posts, {ObjID, Subreddit, Owner, Title, Content, Likes + 1, Dislikes, CreationDate}),
                            LikeID = get_new_id(), 
                            ets:insert(likes, {LikeID, ObjID, Username, upvote})
                    end, 
                    userops:add_karma_to_user(Owner, 1); 
                downvote -> 
                    % 
                    Res = ets:match_object(likes, {'_', ObjID, Username, '_'}), 
                    case Res of 
                        [{LikeID, ObjectID, Username, Mode}] -> 
                            case Mode of 
                                upvote -> 
                                    % Disliking a previously liked post
                                    ets:insert(likes, {LikeID, ObjectID, Username, downvote}), 
                                    ets:insert(posts, {ObjID, Subreddit, Owner, Title, Content, Likes - 1, Dislikes + 1, CreationDate}),
                                    true; 
                                downvote -> 
                                    % Cannot dislike a post twice
                                    false 
                            end; 
                        _ -> 
                            ets:insert(posts, {ObjID, Subreddit, Owner, Title, Content, Likes, Dislikes + 1, CreationDate}),
                            LikeID = get_new_id(), 
                            ets:insert(likes, {LikeID, ObjID, Username, downvote})

                    end,     
                    userops:add_karma_to_user(Owner, -1)
            end,
            true;
        _ -> 
            false 
    end.


edit_post_likes(comments, ObjID, Mode) -> 
    Search = ets:lookup(comments, ObjID), 
    case Search of 
        [{CommentID, Owner, ParentID, Content, Likes, Dislikes, CreationDate}] -> 
            case Mode of 
                upvote -> 
                    ets:insert(comments, {CommentID, Owner, ParentID, Content, Likes + 1, Dislikes, CreationDate}),
                    userops:add_karma_to_user(Owner, 1); 
                downvote -> 
                    ets:insert(comments, {CommentID, Owner, ParentID, Content, Likes, Dislikes + 1, CreationDate}), 
                    userops:add_karma_to_user(Owner, -1)
            end,
            true;
        _ -> 
            false 
    end. 


% get posts from subreddit: 
get_posts_subreddit(SubredditName) ->
    Search = ets:member(subreddits, SubredditName), 
    case Search of 
        true -> 
            List = ets:match_object(posts, {'_', SubredditName, '_', '_', '_', '_', '_', '_'}), 
            {true, List}; 
        _ -> 
            {false, []} 
    end. 

% get comments
get_comments(ParentID) -> 
    ets:match_object(comments, {'_', '_', ParentID, '_', '_', '_', '_'}). 


upvote_item(ObjectID) -> 
    Type = get_type(ObjectID), 
    edit_post_likes(Type, ObjectID, upvote). 

downvote_item(ObjectID) -> 
    Type = get_type(ObjectID), 
    edit_post_likes(Type, ObjectID, downvote). 


get_feed_unpacked(Username) ->
    Ans = ets:lookup(user_info, Username),
    case Ans of
        [{_, _, Feed, _, _, _}] -> 
            UnpackedPosts = [lists:nth(1, ets:lookup(posts, PostID)) || PostID <- Feed],
            {success, UnpackedPosts}; 
        _ -> 
            {failed} 
    end. 


init(Tables) -> 
    delete_tables(Tables),
    create_tables(Tables), 
    listen(). 


listen() ->
    receive 
        {user_register, {Username, Password}, ClientPID} -> 
            Code = register_new_user(Username, Password), 
            case Code of 
                true -> 
                    ClientPID ! {success}; 
                false -> 
                    ClientPID ! {failed}
            end, 
            listen(); 
        {login, {Username, Password}, ClientPID} -> 
            {Result, SessionToken} = authenticate_user(Username, Password),
            case Result of 
                true -> 
                    % Generate Session Token here
                    ClientPID ! {success, SessionToken}; 
                false -> 
                    ClientPID ! {failed}
            end, 
            listen(); 
        {create_subreddit, {SessionToken, SubredditName, Description}, ClientPID} ->
            Username = get_username(SessionToken), 
            case Username of
                false -> 
                    ClientPID ! {failed};
                _ -> 
                Res = create_subreddit(Username, SubredditName, Description),
                case Res of 
                    true -> 
                        ClientPID ! {success};
                    false -> 
                        ClientPID ! {failed}
                end
            end,  
            listen();
        {user_logout, {Token}, ClientPID} -> 
            Result = logout_user(Token), 
            case Result of 
                true -> 
                    ClientPID ! {success};
                false ->
                    ClientPID ! {failed}
            end, 
            listen(); 
        {create_post, {Token, SubredditName, PostTitle, Contents}, ClientPID}  -> 
            Username = get_username(Token),  
            case Username of 
                false -> 
                    ClientPID ! {failed};
                _ ->
                    % Create post 
                    Res = create_post(Username, SubredditName, PostTitle, Contents), 
                    case Res of 
                        true -> ClientPID ! {success};
                        false -> ClientPID ! {failed}
                    end
            end, 
            listen(); 
        {create_comment, {Token, ParentID, Content}, ClientPID} -> 
            Username = get_username(Token), 
            case Username of 
                false -> 
                    ClientPID ! {failed};
                _ -> 
                    % Create Post
                    Res = create_comment(Username, ParentID, Content), 
                    case Res of 
                        true -> ClientPID ! {success}; 
                        false -> ClientPID ! {failed}
                    end
            end, 
            listen(); 
        {upvote, {Token, ObjectID}, ClientPID} -> 
            Username = get_username(Token),
            case Username of 
                false -> 
                    ClientPID ! {failed};
                _ -> 
                    % like post
                    Res = upvote_item(ObjectID), 
                    case Res of 
                        true -> ClientPID ! {success}; 
                        false -> ClientPID ! {failed}
                    end
            end,
            listen(); 
        {downvote, {Token, ObjectID}, ClientPID} -> 
            Username = get_username(Token), 
            case Username of 
                false -> 
                    ClientPID ! {failed}; 
                _ -> 
                    Res = downvote_item(ObjectID), 
                    case Res of 
                        true -> ClientPID ! {success}; 
                        false -> ClientPID ! {failed}
                    end
            end, 
            listen(); 
        {get_posts_subreddit, {Subreddit}, ClientPID} ->  
            {Status, PostList} = get_posts_subreddit(Subreddit), 
            case Status of 
                false -> 
                    ClientPID ! {failed}; 
                true -> 
                    ClientPID ! {success, PostList}
            end, 
            listen(); 
        {get_comments, {ParentID}, ClientPID} -> 
            CommentList = get_comments(ParentID), 
            ClientPID ! {success, CommentList}, 
            listen();
        {join_subreddit, {Token, SubredditName}, ClientPID} -> 
                Username = get_username(Token), 
                case Username of 
                    false -> 
                        ClientPID ! {failed};
                    _ -> 
                        userops:add_subreddit_to_user(Username, SubredditName), 
                        ClientPID ! {success}
                end;
        {leave_subreddit, {Token, SubredditName}, ClientPID} -> 
                Username = get_username(Token), 
                case Username of 
                    false -> 
                        ClientPID ! {failed}; 
                    _  -> 
                        userops:remove_subreddit_from_user(Username, SubredditName),
                        ClientPID ! {success}
                end; 
        {get_feed, {Token}, ClientPID} -> 
            Username = get_username(Token), 
            case Username of 
                false -> 
                    ClientPID ! {failed}; 
                _ -> 
                    get_feed_unpacked(Username)
            end
    end. 


delete_tables(Tables) ->
    lists:foreach(fun(X) -> 
        case ets:info(X) of
            undefined -> 
                ok;
            _ -> 
                ets:delete(X)
        end
    end, Tables).
   

create_tables(Tables) -> 
    lists:foreach(fun(X) -> 
        ets:new(X, [set, named_table, public])
    end, Tables).
    

start() -> 
    Tables = [user_auth, user_info, subreddits, posts, likes, comments, session, direct_msg, subscriptions], 
    spawn(server, init, [Tables]). 

    
    
