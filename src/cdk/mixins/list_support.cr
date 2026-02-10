module CDK
  module ListSupport
    # Looks for a subset of a word in the given list
    def search_list(list : Array(String), list_size : Int32, pattern : String) : Int32
      index = -1
      return index if pattern.empty?

      (0...list_size).each do |x|
        len = {list[x].size, pattern.size}.min
        ret = list[x][0...len] <=> pattern

        if ret < 0
          index = x
        else
          index = x if ret == 0
          break
        end
      end

      index
    end
  end
end
