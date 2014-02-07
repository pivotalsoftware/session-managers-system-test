# Copyright 2014 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'format_duration'
require 'pathname'
require 'rest_client'
require 'tmpdir'

shared_context 'tomcat_helper' do

  let(:tomcat_metadata) { { location: Pathname.new(Dir.mktmpdir), http_port: 8081, shutdown_port: 8001 } }

  let(:cache_file) { Pathname.new('vendor/tomcat.tar.gz') }

  before do |example|
    with_timing('Starting Tomcat...') do
      untar_tomcat tomcat_metadata[:location]
      replace_server_xml example.metadata[:fixture], tomcat_metadata[:location]
      deploy_war tomcat_metadata[:location]
      start_tomcat tomcat_metadata[:location], tomcat_metadata[:shutdown_port], tomcat_metadata[:http_port]
    end
  end

  after do
    with_timing('Stopping Tomcat...') do
      stop_tomcat tomcat_metadata[:location], tomcat_metadata[:shutdown_port]
      tomcat_metadata[:location].rmtree
    end
  end

  def replace_server_xml(server_xml, dir)
    FileUtils.copy "spec/fixtures/#{server_xml}.xml", "#{dir}/conf/server.xml"
  end

  def start_tomcat(dir, shutdown_port, http_port)
    `JAVA_OPTS=\"-Dshutdown.port=#{shutdown_port} -Dhttp.port=#{http_port}\" #{dir}/bin/catalina.sh start`
    wait_for_start(http_port)
  end

  def stop_tomcat(dir, shutdown_port)
    `JAVA_OPTS=\"-Dshutdown.port=#{shutdown_port}\" #{dir}/bin/catalina.sh stop`
  end

  def untar_tomcat(dir)
    `tar zxf #{cache_file} --strip 1 --exclude \'webapps\' -C #{dir}`
  end

  def deploy_war(dir)
    FileUtils.makedirs "#{dir}/webapps" unless Dir.exist? "#{dir}/webapps"
    FileUtils.copy 'test-application/target/application.war', "#{dir}/webapps/ROOT.war"
  end

  def wait_for_start(http_port)
    response = nil
    until response && response.body == 'ok'
      response = RestClient.get "http://localhost:#{http_port}"
    end
  rescue Errno::ECONNREFUSED
    retry
  end

  def with_timing(caption)
    start_time = Time.now
    print "#{caption} "

    yield

    puts "(#{(Time.now - start_time).duration})"
  end

end