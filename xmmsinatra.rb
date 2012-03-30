#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'
require 'erb'
require 'xmmsclient'

Conn = Xmms::Client.new('XMMSinatra').connect(ENV['XMMS_PATH'])

get '/' do
        erb :index
end 

get '/info' do
        content_type 'text/json'

        id = Conn.playback_current_id.wait.value

        if (!id)
                %({"id": "", "artist": "", "album": "", "title": ""})
        else
                info = Conn.medialib_get_info(id).wait.value.to_propdict
                if (!info[:title].nil?)
                        title = info[:title]
                else
                        title = info[:url]
                end
                %({"id": "#{info[:id]}", "artist": "#{info[:artist]}", "album": "#{info[:album]}", "title": "#{title}"})
        end
end

get '/playlist' do
        content_type 'text/json'

        body = %({"items": [)
        Conn.playlist.entries.wait.value.each_with_index do |id, index|
                if (id.zero?)
                        next
                end
                info = Conn.medialib_get_info(id).wait.value.to_propdict
                if (!index.zero?)
                        body += ','
                end
                if (!info[:title].nil?)
                        title = info[:title]
                else
                        title = info[:url]
                end
                body += %({"id": "#{info[:id]}", "artist": "#{info[:artist]}", "album": "#{info[:album]}", "title": "#{title}"})
        end

        body += ']}'
        body
end

get '/art/:id' do |id|
        content_type 'image/jpeg'

        info = Conn.medialib_get_info(id.to_i).wait.value.to_propdict

        if (info[:picture_front])
                Conn.bindata_retrieve(info[:picture_front]).wait.value
        else
                send_file 'nocover.png'
        end
end

get '/search/:query' do |query|
        c = Xmms::Collection.parse(query)

        reply = Conn.coll_query_ids(c).wait.value

        if (reply.length > 0)
                Conn.playlist.clear.wait

                reply.each do |id|
                        if (id.zero?)
                                next
                        end
                        Conn.playlist.add_entry(id).wait
                end

                "OK"
        else
                "FAIL"
        end
end

get '/select/:id' do |id|
        Conn.playlist_set_next(id.to_i - 1).wait
        Conn.playback_tickle.wait
end

get '/playpause' do
        if (Conn.playback_status.wait.value == Xmms::Client::PLAY)
                Conn.playback_pause.wait
        else
                Conn.playback_start.wait
        end
end

get '/prev' do
        Conn.playlist_set_next_rel(-1).wait
        Conn.playback_tickle.wait
end

get '/next' do
        Conn.playlist_set_next_rel(1).wait
        Conn.playback_tickle.wait
end

__END__

@@ index
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
        <head>
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                <title>XMMSinatra</title>
                <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>
                <link rel="stylesheet" type="text/css" href="style.css" />
                <link rel="icon" type="image/png" href="/favicon.ico" />
        </head>
        <body>
                <div id="header">
                        <a href="http://github.com/ZaneA/XMMSinatra" target="_blank">XMMSinatra</a>
                </div>

                <div id="info">
                        <span id="id"></span>
                        <span id="artist"></span>
                        <span id="title"></span>
                        <span id="album"></span>
                </div>

                <div id="menu">
                        <ul>
                                <li><a id="previous"><img src="media-previous-inv.png" /></a></li>
                                <li><a id="playpause"><img src="media-play-pause-resume-inv.png" /></a></li>
                                <li><a id="next"><img src="media-next-inv.png" /></a></li>
                        </ul>
                        <ul>
                                <li><input type="text" id="search" value="Search" /></li>
                        </ul>
                </div>

                <div id="playlist">
                </div>

                <script type="text/javascript">
                        $(function () {
                                var lastAlbum = "";

                                $("#playlist").click(function (e) {
                                        if ($(e.target).parent().is(".item")) {
                                                $.get('/select/' + $(e.target).parent().find(".pid").html());
                                                setTimeout(updateInfo, 500);
                                        }
                                });

                                function updateInfo() {
                                        $.getJSON("/info", function (data) {
                                                if (data.id != $("#id").html()) {
                                                        $("#id").html(data.id);
                                                        $("#artist").html(data.artist);
                                                        $("#title").html(data.title.replace(/ \(.*?\)/, ''));
                                                        $("#album").html(data.album.replace(/ \(.*?\)/, ''));
                                                        document.title = data.title + " - " + data.artist + " - XMMSinatra";
                                                        updatePlaylist();
                                                }
                                        });
                                };

                                function updatePlaylist() {
                                        $("#playlist").html("");
                                        lastAlbum = "";

                                        $.getJSON("/playlist", function (data) {
                                                $.each(data.items, function (i, item) {
                                                        if (lastAlbum != item.album) {
                                                                lastAlbum = item.album;
                                                                $("#playlist").append("<div class=\"albumitem\">" + item.album + "</div>");
                                                                $("#playlist").append("<div class=\"albumartwrap\"><img class=\"albumart\" src=\"/art/" + item.id + "\" /></div>");
                                                        }

                                                        if (item.id == $("#id").html()) {
                                                                $("#playlist").append("<div class=\"item active\"><span class=\"pid\">" + (i + 1) + "</span><span class=\"id\">" + item.id + "</span><span class=\"artist\">" + item.artist + "</span><span class=\"title\">" + item.title + "</span></div>");
                                                        } else {
                                                                $("#playlist").append("<div class=\"item\"><span class=\"pid\">" + (i + 1) + "</span><span class=\"id\">" + item.id + "</span><span class=\"artist\">" + item.artist + "</span><span class=\"title\">" + item.title + "</span></div>");
                                                        }
                                                });
                                        });
                                };

                                updateInfo();
                                setInterval(updateInfo, 10000);

                                $("#playpause").click(function () {
                                        $.get('/playpause');
                                });

                                $("#previous").click(function () {
                                        $.get('/prev');
                                        setTimeout(updateInfo, 500);
                                });

                                $("#next").click(function () {
                                        $.get('/next');
                                        setTimeout(updateInfo, 500);
                                });

                                $("#search").keydown(function (event) {
                                        $("#search").removeClass("invalid");

                                        if (event.which == 13) {
                                                $.get("/search/" + $("#search").val(), function (data) {
                                                        if (data == "OK")
                                                                updatePlaylist();
                                                        else
                                                                $("#search").addClass("invalid");
                                                });
                                        }
                                });

                                $(".item").click(function () {
                                        $.get('/select/' + $(this).find(".pid").html());
                                        setTimeout(updateInfo, 500);
                                });
                        });
                </script>
        </body>
</html>

