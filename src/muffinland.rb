# Welcome to Muffinland, the lazy CMS (or something)
# Alistair Cockburn and a couple of really nice friends
# 2014-07-27 basic tagging put back in. wanting a "request-parser" thing
# ideas: email, DTO test,

require 'rack'
require 'erb'
require 'erubis'
require 'logger'
require 'set'
require_relative './mrequest.rb'



#===== These i/o utilities should be in a shared place one day =====
def page_from_template( templateFullFn, binding )
    pageTemplate = Erubis::Eruby.new(File.open( templateFullFn, 'r').read)
    pageTemplate.result(binding)
end

def zapout( str )
  print "\n #{str} \n"
end

#=========================================
# Muffinland know global policies and environment, not histories and private things.
class Muffinland

  def initialize(viewsFolder)
    @theHistorian = Historian.new # knows the history of requests
    @theBaker = Baker.new         # knows the muffins
    @viewsFolder = viewsFolder    # I could hope this goes away one day, ugh.
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
  end

  def call(env) #this is the Rack Request chain that for Rack-driven use
    mlResult = handle(        # all 'handle's return 'mlResult'
        MRackRequest.new(     # Mrequests wrap various request types/sources
            Rack::Request.new(env) ) )

    @log.info("Result Pack:" + mlResult.inspect)

    page = page_from_template(
        @viewsFolder + mlResult[:html_template_fn],
        binding )
    response = Rack::Response.new
    response.write( page )
    response.finish
  end
end

def handle( request ) # expects Mrequest; all 'handle's return 'mlResult'
  mlResult =
      case
        when request.get? then handle_get_muffin(request)
        when request.post? then handle_post(request)
      end
end

#===== GETs =====
def handle_get_muffin( request )
  muffin = @theBaker.muffin_at_GET_request( request ) # might be nil
  mlResult =
      case
        when @theHistorian.no_history_to_report
          mlResult_for_EmptyDB
        when muffin
          mlResult_for_GET_muffin( muffin )
        else
          mlResult_for_404_basic( request )
      end
end

def mlResult_for_EmptyDB
  mlResult = { :html_template_fn => "EmptyDB.erb" }
end

def mlResult_for_404_basic( request )
  mlResult = {
      :html_template_fn => "404.erb",
      :requested_name => request.name_from_GET_path,
      :dangerously_all_muffins =>
          @theBaker.dangerously_all_muffins.map{|muff|muff.raw},
      :dangerously_all_posts =>
          @theHistorian.dangerously_all_posts.map{|req|
            req.name_from_params }
      }
end

def mlResult_for_GET_muffin( muffin )
  mlResult = {
      :html_template_fn => "GET_named_page.erb",
      :muffin_id => muffin.id,
      :muffin_body => muffin.raw,
      :tags => muffin.dangerously_all_tags,
      :dangerously_all_muffins =>
          @theBaker.dangerously_all_muffins.map{|muff|muff.raw},
      :dangerously_all_posts =>
          @theHistorian.dangerously_all_posts.map{|req|req.inspect}
      }
end


#===================================================
def handle_post( request ) # expect Rack::Request, emit Rack::Response
  @log.info("Just received POST:" + request.inspect)
  @theHistorian.add_request( request )
  case
    when request.is_Add_command?    then  handle_add_muffin(request)
    when request.is_Change_command? then  handle_change_muffin(request)
    when request.is_Tag_command?    then  handle_tag_muffin(request)
    else                                  print "DOIN NUTHNG"
  end
end

def handle_add_muffin( request )
  m = @theBaker.add_muffin(request)
  mlResult_for_GET_muffin( m )
end

def handle_change_muffin( request )
  m = @theBaker.change_muffin_per_request( request )
  m ?
      mlResult_for_GET_muffin( m ) :
      mlResult_for_404_basic( request )
end

def handle_tag_muffin( request )
  muffin_name, muffin_id = request.nameAndID_from_params
  @theBaker.tag_muffin_per_request( request ) ?
      mlResult_for_GET_muffin( muffin ) :
      mlResult_for_404_basic( request )
end


#===================
class Muffin

  def initialize( id, request)
    @myID = id
    new_contents_from_request( request )
    @myTags = Set.new
        @log = Logger.new(STDOUT)
        @log.level = Logger::INFO
  end

  def raw
    @myRaw
  end

  def id
    @myID
  end

  def new_contents_from_request( request )
    @myRaw = request.incoming_muffin_contents
  end

  def add_tag( n ); @myTags << n; end

  def dangerously_all_tags; @myTags; end

end

#===================
class Historian # knows the history of what has happened, all Posts

  def initialize
    @thePosts = Array.new
        @log = Logger.new(STDOUT)
        @log.level = Logger::INFO
  end

  def no_history_to_report;  @thePosts.size == 0; end

  def dangerously_all_posts; @thePosts; end #yep, dangerous. remove eventually


  def add_request( request )
    @thePosts << request
  end

end


#===================
class MuffinTin # knows what muffin ids are made from. shhhh top secret.

  def initialize
    @muffins = Array.new
  end

  def next_id  # the ID might or might not be the array index. dont count on it.
    @muffins.size
  end
  
  def is_legit( id )
    (id.is_a? Integer) && ( id > -1 ) && ( id < @muffins.size )
  end

  def at( id )
    @muffins[id]
  end

  def add_raw( content )  # muffinTin not allowed to know what contents are.
    id = next_id
    m = Muffin.new( id, content )
    @muffins << m
    return m
  end

  def dangerously_all_muffins   #yep, dangerous. remove eventually
    @muffins
  end


end

#===================
  class Baker # knows the handlings of muffins.

  def initialize
    @muffinTin = MuffinTin.new
        @log = Logger.new(STDOUT)
        @log.level = Logger::INFO
  end

  def dangerously_all_muffins   #yep, dangerous. remove eventually
    @muffinTin.dangerously_all_muffins
  end 

  def muffin_at_GET_request( request )
    name = request.name_from_GET_path
    id = request.id_from_name( name )
    muffin_at(id) if is_legit(id)
  end

  def muffin_at(id)
    @muffinTin.at( id )
  end

  def is_legit( id )
    @muffinTin.is_legit(id)
  end

  def add_muffin( request ) # modify the Request!, return muffin
    m = @muffinTin.add_raw( request )
    request.record_muffin_id( m.id )  #  modify the defining request!!
    return m
  end



  def change_muffin_per_request( request ) # modify the Request in place; return nil if bad muffin number
    muffin_name, muffin_id = request.nameAndID_from_params
    return nil if !is_legit( muffin_id)
    request.record_muffin_id(muffin_id)  #  modify the defining request!!
    @muffinTin[muffin_id].new_contents_from_request( request )
        @log.info("Changed muffin:" + request.inspect)
    return muffin
  end



  def tag_muffin_per_request( n_ignored, request ) #really want both numbers coming in here.but ok

    muffin_name, muffin_id = request.nameAndID_from_params

    muffin_name = request.requested_muffin_id_str
    muffin_id = number_or_nil( muffin_name )
    return nil if !is_legit( muffin_id ) #FAIL! hopefully UI will stop this

    collector_name = request.collector_name_from_params  #WRONG
    collector_number = number_or_nil( collector_name  )
    return if !is_legit( collector_number ) #FAIL! hopefully UI will stop this


    request.record_muffin_id(muffin_id)
    request.record_collector_ID(collector_number)

    @muffinTin[muffin_id].add_tag(collector_number)

        @log.info("Received tag request with details:" + request.inspect)
    return muffin_id
  end

end



#====================================

def number_or_nil(string)
  Integer(string)
rescue ArgumentError
  nil
end


#==================================
# Mrequest is the class hierarchy that know what
# flavor of request is coming into Muffinland.
# Could be a Rack::Request or a DTORequest for testing

class Mrequest

  #nothing implemented at this level yet.

end


#==================================
# a Rack::Request wrapper

class MRackRequest < Mrequest
  require 'rack'
  require 'rack/test'
  require 'logger'

  def initialize( rack_request )
    @myMe = rack_request
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO

  end

  def get?
    @myMe.get?
  end

  def post?
    @myMe.post? || @myMe.path=="/post"
  end

  def is_Add_command?
    @myMe.params.has_key?("Add")
  end

  def is_Change_command?
    @myMe.params.has_key?("Change")
  end

  def is_Tag_command?
    @myMe.params.has_key?("Tag")
  end

  def name_from_GET_path
    path = @myMe.path
    path[1..path.size]
  end

  def id_from_name( name )
    number_or_nil(name)
  end

  def name_from_params
    @myMe.params["MuffinNumber"]
  end

  def incoming_muffin_contents
    @myMe.params["MuffinContents"]
  end

  def collector_name_from_params
    @myMe.params["CollectorNumber"]
  end

  def record_muffin_id( n )
    @myMe.env["muffinID"] = n.to_s
  end

  def record_collector_ID( n )
    @myMe.env["collectorID"] = n.to_s
  end



end