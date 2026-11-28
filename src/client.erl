-module(client).
-compile(export_all).
-compile(nowarn_export_all). 



% Reddit PID is the process ID of the Reddit Server
register(RedditPID, Username, Password) ->
    RedditPID ! {user_register, {Username, Password}, self()}, 
    receive
        {success} -> 
            io:format("Client: Successful Register~n");
        {failed} -> 
            io:format("Client: Failed Register~n")
    end. 



login(RedditPID, Username, Password) -> 
    RedditPID ! {login, {Username, Password}, self()}, 
    receive
        {success, SessionID} -> 
            io:format("Client: Login Successful ~n"), 
            SessionID; 
        {failed} -> 
            io:format("Client: Login Failed ~n"),
            -1 
    end. 


create_subreddit(RedditPID, Token, SubredditName, SubredditDescription) -> 
    RedditPID ! {create_subreddit, {Token, SubredditName, SubredditDescription}, self()}, 
    receive 
        {success} -> 
            io:format("Client: Sucessfully Created Subreddit ~n"); 
        {failed} -> 
            io:format("Client: Subreddit Creation Failed ~n")
    end. 


logout(RedditPID, Token) -> 
    RedditPID ! {user_logout, {Token}, self()}, 
    receive 
        {success} -> 
            io:format("Client: Logout Successful ~n"); 
        {failed} -> 
            io:format("Client: Logout Failed ~n")
    end. 


create_post(RedditPID, Token, SubredditName, PostTitle, Contents) -> 
    RedditPID ! {create_post, {Token, SubredditName, PostTitle, Contents}, self()}, 
    receive 
        {success} -> 
            io:format("Client: Post Created Successfully ~n"); 
        {failed} -> 
            io:format("Client: Post Creation Unsuccessful ~n")
    end. 

create_comment(RedditPID, Token, ParentID, Contents) -> 
    RedditPID ! {create_comment, {Token, ParentID, Contents}, self()}, 
    receive 
        {success} -> 
            io:format("Client: Comment Created Successfully ~n"); 
        {failed} -> 
            io:format("Client: Comment Creation Unsuccessful ~n")
    end. 


upvote(RedditPID, Token, ObjectID) -> 
    RedditPID ! {upvote, {Token, ObjectID}, self()},
    receive 
        {success} -> 
            io:format("Client: Upvote Successful ~n");
        {failed} -> 
            io:format("Client: Upvote Failed ~n")
    end. 


downvote(RedditPID, Token, ObjectID) -> 
    RedditPID ! {downvote, {Token, ObjectID}, self()},
    receive 
        {success} -> 
            io:format("Client: Downvote Successful~n");
        {failed} -> 
            io:format("Client: Downvote Failed~n")
    end.  


get_posts_subreddit(RedditPID, SubredditName) -> 
    RedditPID ! {get_posts_subreddit, {SubredditName}, self()}, 
    receive 
        {success, PostList} -> 
            io:format("Client: Post GET Successful ~n"), 
            PostList; 
        {failed} -> 
            io:format("Client: Post GET Failed ~n")
    end.


join_subreddit(RedditPID, Token, SubredditName) -> 
    RedditPID ! {join_subreddit, {Token, SubredditName}, self()}, 
    receive 
        {success} -> 
            io:format("Client: Sucessfully joined subreddit ~n"); 
        {failed} -> 
            io:format("Client: Failed to join subreddit ~n")
    end. 


leave_subreddit(RedditPID, Token, SubredditName) -> 
    RedditPID ! {join_subreddit, {Token, SubredditName}, self()}, 
    receive 
        {success} -> 
            io:format("Client: Sucessfully left subreddit ~n"); 
        {failed} -> 
            io:format("Client: Failed to leave subreddit ~n")
    end. 

get_feed(RedditPID, Token) -> 
    RedditPID ! {get_feed, {Token}, self()}, 
    receive 
        {success, Feed} ->
            io:format("Client: Successfuly received Feed. ~n"), 
            Feed; 
        {failed} -> 
            io:format("Client: Failed to get feed. ~n")
    end. 




get_comments(RedditPID, ParentID) -> 
    RedditPID ! {get_comments, ParentID}, 
    receive 
        {success, CommentList} -> 
            io:format("Client: Comment Get Successful ~n"),
            CommentList
    end. 








