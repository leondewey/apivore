require 'apivore/rspec_builder'
require 'apivore/rspec_matchers'

module Apivore
  class ApiDescription
    attr_reader :swagger_version, :base_path, :substitutions
    def initialize(swagger)
      @json = JSON.parse(swagger)
      @swagger_version = @json['swagger']
      @apis = @json['apis']
      @base_path = @json['basePath']
    end

    def validate(version)
      case version
      when '2.0'
        schema = File.read(File.expand_path("../../data/swagger_2.0_schema.json", __FILE__))
      else
        raise "Unknown/unsupported Swagger version to validate against: #{version}"
      end
      JSON::Validator.fully_validate(schema, @json)
    end

    def valid(version)
      validate(version) == []
    end

    def paths(filter = nil)
      result = @json['paths'].collect { |p| Path.new(p, self) }
      unless filter.nil?
        result.select! { |p| p.has_method?(filter) }
      end
      result
    end

    def get_definition(ref)
      path = ref.split('/')[1..-1]
      d = @json
      begin
        path.each { |p| d = d[p] }
      rescue
        raise "Unable to find definition section in the api description!"
      end
      d
    end
  end

  class Path
    attr_reader :name
    def initialize(path_data, api_description)
      @name = path_data.first
      @api_description = api_description
      @method_data = path_data.last
    end

    def full_path
      @api_description.base_path + @name
    end

    def has_method?(method)
      @method_data.each { |m| return true if m.first == method }
      false
    end

    def schema(method, response = '200')
      if @method_data[method] && @method_data[method]['responses'] && @method_data[method]['responses'][response]
        SchemaObject.new(@method_data[method]['responses'][response], @api_description)
      else
        nil
      end
    end
  end

  class SchemaObject
    def initialize(schema, api_description)
       @body = schema
       @api_description = api_description
    end

    def array?
      @body['schema']['type'] && @body['schema']['type'] == 'array'
    end

    def model
      return nil if !@body['schema']
      if array?
        item = @body['schema']['items']
      else
        item = @body['schema']
      end
      if item['$ref']  # if this is a reference, not the data structure itself
        item = @api_description.get_definition(item['$ref'])
      end
      item
    end
  end
end

