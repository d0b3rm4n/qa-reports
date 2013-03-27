


class BugsController < ApplicationController

  caches_action :fetch_bugzilla_data,
                :cache_path => Proc.new { |controller| controller.bugzilla_cache_key },
                :expires_in => 1.hour

  def fetch_bugzilla_data
    ids  = params[:bugids]
    json = {}

    ids.group_by {|id|
      prefix, id = /([A-Z]{1,}\#{1})?(\d+)/.match(id).try(:captures)
      # Return straight away if something odd has been given
      return head :unprocessable_entity if id.blank?

      # If prefix does not exist or is not any of the defined prefixes
      # we will use the default service. Keeping the bug ids intact because
      # we need to be able to return them in exactly the same form so the
      # client side code knows where to put the value
      prefix.sub! '#', '' unless prefix.nil?
      if prefix.nil? or not SERVICES.map {|s| s['prefix']} .include?(prefix)
        prefix = DEFAULT_SERVICE['prefix'] || "DEFAULT_SERVICE_PREFIX"
      end
      prefix
    } .each {|prefix, ids|
      # Get the service for the prefix
      service = SERVICES.detect {|s| s['prefix'] == prefix}
      # Get the plain IDs to be given to the service handler
      plain_ids = ids.map {|id| plain_id(id)} .uniq

      # TODO: Better way to define what to execute?
      case service['type']
      when 'bugzilla'
        data = Bugzilla.fetch_data(service, plain_ids)
      when 'link'
      end

      # Now we still need to whole shebang - the returned data has all that we
      # need but we do need to return the same IDs as received (e.g. request
      # contained 1234 and BZ#1234, and even if they're the same bug we will
      # return it twice to be able to show the information on correct place
      # and not e.g. for GERRIT#1234)
      ids.each {|id|
        pid      = plain_id(id)
        json[id] = data.detect {|bug| bug[:id] == pid}
      }
    }

    if json.blank?
      head :not_found
    else
      render :json => json
    end
  end

  protected

  def bugzilla_cache_key
    h = Digest::SHA1.hexdigest params.to_hash.to_a.map{|k,v| if v.respond_to?(:join) then k+v.join(",") else k+v end}.join(';')
    "bugzilla_#{h}"
  end

  def plain_id(str)
    /(?:[A-Z]{1,}\#{1})?(\d+)/.match(str).captures[0]
  end

end
