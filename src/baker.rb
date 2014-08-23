require 'logger'
require 'set'


class MuffinTin
# known only by the Baker, the MuffinTin
# knows what muffin ids are made from. shhhh top secret.
# The Baker adds, finds, modifies muffins via the MuffinTin

  def initialize
    @muffins = Array.new
  end

  def at( id ) ; @muffins[id]  ;  end
  def next_id ;  @muffins.size ;  end

  def is_legit?( id )
    (id.is_a? Integer) && ( id > -1 ) && ( id < @muffins.size )
  end

  def add_raw( content )  # muffinTin not allowed to know what contents are.
    m = Muffin.new( next_id, content )
    @muffins << m
    return m
  end

  def add_raw_from_file( content, content_type )  # muffinTin not allowed to know what contents are.
    m = Muffin.new( next_id, content, content_type )
    @muffins << m
    return m
  end

  def dangerously_all_muffins   #yep, dangerous. remove eventually
    @muffins
  end

end

#===== class Baker ==============
# knows the handlings of muffins.

class Baker

  def initialize
    @muffinTin = MuffinTin.new
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
  end

  def muffin_at(id) ;  @muffinTin.at( id ) ;  end
  def is_legit?(id) ;  @muffinTin.is_legit?(id) ;  end

  def dangerously_all_muffins   #yep, dangerous. remove eventually
    @muffinTin.dangerously_all_muffins
  end

  def muffin_at_GET_request( request )
    id = request.id_from_path   # not sure why Baker knows request from path. suspect
    muffin_at(id) if is_legit?(id)
  end


  def add_muffin( request ) # modify the Request!
    m = @muffinTin.add_raw( request.incoming_contents )
    request.record_muffin_id( m.id )  #  Look Out! modify the defining request!!
    #the reason for this is this is the only record of the id of the new muffin
    return m
  end


  def add_muffin_from_file( request ) # modify the Request!
    t = request.content_type_of_file_upload
    c = request.content_of_file_upload
    @log.info "File uploaded: t,c: #{t.inspect} & #{c.inspect}"
    m = @muffinTin.add_raw_from_file( c, t )
    request.record_muffin_id( m.id )
    return m
  end


  def change_muffin_per_request( request )
    return nil if !is_legit?( id = request.incoming_muffin_id )
    m = muffin_at( id )
    m.new_contents( request.incoming_contents )
    m
  end


  def tag_muffin_per_request( request )
    return nil if !is_legit?( id = request.incoming_muffin_id )
    collector_id = request.incoming_collector_id
    return nil if !is_legit?( collector_id )
    m = muffin_at( id )
    m.add_tag( collector_id )
    m
  end

end


