require 'rubygems'
require 'sinatra'
require 'erb'
require 'xmmsclient'

xmms = Xmms::Client.new('XMMSinatra').connect(ENV['XMMS_PATH'])

get '/' do
        erb :index
end 

get '/style.css' do
        content_type "text/css"

        File.read('style.css')
end

get '/info' do
        content_type "text/json"

        @id = xmms.playback_current_id.wait.value

        if (@id == 0)
                "{\"id\": \"\", \"artist\": \"\", \"album\": \"\", \"title\": \"\"}"
        else
                @info = xmms.medialib_get_info(@id).wait.value.to_propdict
                "{\"id\": \"#{@info[:id]}\", \"artist\": \"#{@info[:artist]}\", \"album\": \"#{@info[:album]}\", \"title\": \"#{@info[:title]}\"}"
        end
end

get '/playlist' do
        content_type "text/json"

        @body = "{\"items\": ["
        xmms.playlist.entries.wait.value.each_with_index do |id, index|
                if (id.zero?)
                        next
                end
                @info = xmms.medialib_get_info(id).wait.value.to_propdict
                if (!index.zero?)
                        @body += ","
                end
                @body += "{\"id\": \"#{@info[:id]}\", \"artist\": \"#{@info[:artist]}\", \"album\": \"#{@info[:album]}\", \"title\": \"#{@info[:title]}\"}"
        end

        @body += "]}"
        @body
end

get '/art/:id' do |id|
        content_type "image/jpeg"

        @info = xmms.medialib_get_info(id.to_i).wait.value.to_propdict

        if (@info[:picture_front])
                xmms.bindata_retrieve(@info[:picture_front]).wait.value
        else
                File.read('nocover.png')
        end
end

get '/search/:query' do |query|
        @c = Xmms::Collection.parse(query)

        xmms.playlist.clear.wait

        xmms.coll_query_ids(@c).wait.value.each do |id|
                if (id.zero?)
                        next
                end
                xmms.playlist.add_entry(id).wait
        end

        ""
end

get '/select/:id' do |id|
        xmms.playlist_set_next(id.to_i - 1).wait
        xmms.playback_tickle.wait
end

get '/pause' do
        xmms.playback_pause.wait
end

get '/play' do
        xmms.playback_start.wait
end

get '/prev' do
        xmms.playlist_set_next_rel(-1).wait
        xmms.playback_tickle.wait
end

get '/next' do
        xmms.playlist_set_next_rel(1).wait
        xmms.playback_tickle.wait
end
