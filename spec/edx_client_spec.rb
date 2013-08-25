
  context 'when initialized' do

    it "config elements should be set up correctly" do
      conf = {}
      conf['queue_uri'] = 'https://test.com/live-queue'
      conf['autograders_yml'] = './config/autograders.yml'
      conf['user_auth'] = {"user_name"=>"user-name", "user_pass"=>"user-password"}
      conf['django_auth'] = {"username"=>"django-user", "password"=>"django-password"}
      conf['halt'] = false
      conf['sleep_duration'] = 30

      EdXClient.should_receive(:load_configurations).with('live').and_return(conf)

      auto_conf = {'assign-0-queue'=>{}}
      auto_conf['assign-0-queue'][:name] = 'test-pull'
      auto_conf['assign-0-queue'][:type] = 'WeightedRspecGrader'

      EdXClient.should_receive(:init_autograders).with('./config/autograders.yml').and_return(auto_conf)

      client = EdXClient.new('live')
      client.instance_eval{@endpoint}.should == 'https://test.com/live-queue'
      client.instance_eval{@user_auth}.should == ["user-name","user-password"]
      client.instance_eval{@django_auth}.should == ["django-user", "django-password"]
      #client.instance_eval{@autograders}.should == {
      #    'test-assign-1-part-1' => { uri: 'http://test.url/', type: 'WeightedRspecGrader'},
      #}
    end

  end

  it "loads configurations" do
    conf_yml = <<EOF
staging:
  queue_uri: https://test.com/staging-queue
  autograders_yml: ./config/autograders.yml
  django_auth:
    username: 'django-user'
    password: 'django-password'
  user_auth:
    user_name: 'user-name'
    user_pass: 'user-password'
  halt: false # default: true, exit when all submission queues are empty
  sleep_duration: 30 # default 300, time in seconds to sleep when all queues are empty, only valid when halt == false doesn't matter yet

live:
  queue_uri: https://test.com/live-queue
  autograders_yml: ./config/autograders.yml
  django_auth:
    username: 'django-user'
    password: 'django-password'
  user_auth:
    user_name: 'user-name'
    user_pass: 'user-password'
  halt: false # default: true, exit when all submission queues are empty
  sleep_duration: 30 # default 300, time in seconds to sleep when all queues are empty, only valid when halt == false doesn't matter yet
EOF


      File.should_receive(:file?).and_return true
      File.should_receive(:open).with('config/conf.yml','r').and_return(conf_yml)
      conf = EdXClient.load_configurations('live')
      conf['queue_uri'].should eq 'https://test.com/live-queue'
      conf['user_auth'].should eq({"user_name"=>"user-name", "user_pass"=>"user-password"})
      conf['django_auth'].should eq({"username"=>"django-user", "password"=>"django-password"})
      conf['halt'].should be_false
      conf['sleep_duration'].should eq 30
      conf['autograders_yml'].should eq './config/autograders.yml'
      File.should_receive(:file?).and_return true
      File.should_receive(:open).with('config/conf.yml','r').and_return(conf_yml)
      conf = EdXClient.load_configurations('staging')
      conf['queue_uri'].should eq 'https://test.com/staging-queue'
  end

  it 'loads autograder specific configuration' do
    autograder_conf_yml = <<EOF
assign-0-queue:
  name: "test-pull"
  type: WeightedRspecGrader
  due:  20130822205959
  grace_period: 7
  parts:
    assign-0-part-1:
      uri: ../hw/solutions/part1_spec.rb
      type: WeightedRspecGrader
    assign-0-part-2:
      uri: ../hw/solutions/part2_spec.rb
      type: WeightedRspecGrader
    assign-0-part-3:
      uri: ../hw/solutions/part3_spec.rbl
      type: WeightedRspecGrader
EOF
    File.should_receive(:open).with('./config/autograders.yml','r').and_return(autograder_conf_yml)
    autograders = EdXClient.init_autograders('./config/autograders.yml')
    autograders['assign-0-queue'][:name].should eq 'test-pull'
    autograders['assign-0-queue'][:type].should eq 'WeightedRspecGrader'
  end

  describe "#run" do
    before :each do
      EdXController.stub(:new).and_return(controller)
      autograder = {'test-assignment' => { :uri => 'http://example.com', :type => 'RspecGrader' } }
      conf = {}
      conf['queue_uri'] = 'https://test.com/live-queue'
      conf['autograders_yml'] = './config/autograders.yml'
      conf['user_auth'] = {"user_name"=>"user-name", "user_pass"=>"user-password"}
      conf['django_auth'] = {"username"=>"django-user", "password"=>"django-password"}
      conf['halt'] = false
      conf['sleep_duration'] = 30
      EdXClient.stub(:load_configurations).and_return(conf)
      EdXClient.stub(:init_autograders).and_return(autograder)
    end
    let(:controller) { double('fake controller').as_null_object }
    let(:submission) { double('fake_submission').as_null_object }


    context "with one autograder" do

      it 'should exit if the submission queue is empty (under test)' do
        controller.should_receive(:get_queue_length).and_return(0)
        client = EdXClient.new()
        eval("class EdXClient; def continue_running_test(x); x > 0; end; end;")
        client.run
      end

      it 'should authenticate with EdX, grab submission and grade it' do
        controller.should_receive(:get_queue_length).and_return(1,1,0)
        controller.should_receive(:authenticate)
        controller.stub(:get_submission).and_return(submission)
        client = EdXClient.new()
        client.should_receive(:load_spec)
        client.should_receive(:load_due_date)
        client.should_receive(:load_grace_period)
        client.stub(:generate_late_response).and_return(1,"")
        client.should_receive(:write_student_submission)
        client.stub(:run_autograder_subprocess).and_return(100,"woot!")
        client.should_receive(:format_for_html).and_return("woot!")
        controller.should_receive(:send_grade_response)
        eval("class EdXClient; def continue_running_test(x); x > 0; end; end;")
        client.run
      end

    end
  end

end
  let(:controller) { double('fake controller').as_null_object }
  let(:client) { EdXClient.new }
  fake_config = {
    "live" => {
      'queue_uri' => 'uri',
      'autograders_yml' => 'path/ag_path.yml',
      'django_auth' => {
        'username' => 'username',
        'password' => 'password'
      },
      'user_auth' => {
        'username' => 'username',
        'password' => 'password'
      },
      'halt' => true ,
      'sleep_duration' => 169
    }
  }

  fake_autograder = {
    "assignment_one_queue" => {
      :name => "fake_queue",
      :parts => {
        "mock_assignment" => {
            "uri" => "mock_spec.yml",
            "type" => "WeightedRspecGrader"
          }
      }
    }
  }


  let(:fake_yml_ag) { YAML.dump(fake_autograder) }
  let(:fake_yml_config) { YAML.dump(fake_config) }


  context "When initialized" do

    it "should open the conf.yml file" do

      File.should_receive(:file?).with('config/conf.yml').and_return(true)
      File.should_receive(:open).with('path/ag_path.yml', "r").and_return(fake_yml_config)
      File.should_receive(:open).with('config/conf.yml', "r").and_return(fake_yml_config)

      client
    end

    it "should properly deserialize the configuration options" do

      File.should_receive(:file?).with('config/conf.yml').and_return(true)
      File.should_receive(:open).with('path/ag_path.yml', "r").and_return(fake_yml_ag)
      File.should_receive(:open).with('config/conf.yml', "r").and_return(fake_yml_config)

      client.instance_eval{@endpoint}.should eq 'uri'
      client.instance_eval{@user_auth}.should eq ['username', 'password']
      client.instance_eval{@django_auth}.should eq ['username', 'password']
      client.instance_eval{@halt}.should be_true
      client.instance_eval{@sleep_duration}.should eq 169
      client.instance_eval{@autograders}.should eq fake_autograder

    end

    it "should load the autograders file with the path read from conf.yml" do

      File.should_receive(:open).with('path/ag_path.yml', "r").and_return(fake_yml_ag)
      File.should_receive(:file?).with('config/conf.yml').and_return(true)
      File.should_receive(:open).with('config/conf.yml', "r").and_return(fake_yml_config)

      client
    end

    it "should properly load multiple autograders from the autograders file" do
      two_autograders = fake_autograder.merge( {"assignment_two_queue" => fake_autograder["assignment_one_queue"]})
      two_autograders_yml =YAML::dump(two_autograders)
      File.should_receive(:open).with('path/ag_path.yml', "r").and_return(two_autograders_yml)
      File.should_receive(:file?).with('config/conf.yml').and_return(true)
      File.should_receive(:open).with('config/conf.yml', "r").and_return(fake_yml_config)
      autograders = client.instance_eval{@autograders}
      autograders.should eq two_autograders
    end

  end

  context "@halt is true" do
    before :each do
      client.stub(:load_configutation){}
      client.stub(:init_autograder){return {} }
    end

    it "should delete an autograder if it is empty and halt is set to true" do
      controller.should_receive(:get_queue_length).and_return(0)
      client
      client.instance_eval{@autograders.size}.should eq 1
      client.run
      client.instance_eval{@autograders.size}.should eq 0
    end

  end

  describe "#run" do
    before :each do
      client
      metadata = {"submission_time" => 20250101010100, "anonymous_student_id" => "deadbeef1010" }
      student_submission = "puts 'hello world'"
      part_sid = "assignment_one_queue"
      part_name = "mock_assignment"
      AutoGraderSubprocess.stub(:run_autograder_subprocess) {[100,"good job"]}
      client.stub(:each_submission).and_yield(part_sid, student_submission, part_name, metadata)
      FakeFS.activate!
    end

    after :each do
      FakeFS.deactivate!
    end

    it "Should run without error" do
      client.run
    end

    it "Should not raise an error if AutoGraderSubprocess crashes" do
      AutoGraderSubprocess.stub(:run_autograder_subprocess) {raise AutoGraderSubprocess::OutputParseError}
      lambda{client.run}.should_not raise_error()

      AutoGraderSubprocess.stub(:run_autograder_subprocess) {raise AutoGraderSubprocess::SubprocessError}
      lambda{client.run}.should_not raise_error()
    end

    it "Should set the comments and score to the outputs of run_autograder_subprocess" do
      client.stub(:generate_late_response){[1,"on time"]}
      controller.should_receive(:send_grade_response).with(true, 100, "<pre>on time good job</pre>")
      client.run
    end

    it "Should scale the score by the late scaling factor" do
      client.stub(:generate_late_response){[0.75,"A little late"]}
      controller.should_receive(:send_grade_response).with(true, 75.0, "<pre>A little late good job</pre>")
      client.run
    end

    it "Should set checkmark argument to true if 0 points are awarded for being too late" do
      client.stub(:generate_late_response){[0.0,"10 years late"]}
      controller.should_receive(:send_grade_response).with(true, 0.0, "<pre>10 years late good job</pre>")
      client.run
    end

    it "Should set checkmark argument to false if no points are earned from the tests" do
      AutoGraderSubprocess.stub(:run_autograder_subprocess) {[0,"Try again!"]}
      client.stub(:generate_late_response){[1,"on time"]}
      controller.should_receive(:send_grade_response).with(false, 0, "<pre>on time Try again!</pre>")
      client.run
    end
  end

  context "Due dates and late penalties" do
    it "#load_due_date should raise an error if called with invalid part-sid" do
      lambda {client.send(:load_due_date, "nonexistant_sid" )}.should raise_error
    end

    it "#load_due_date should set a due date in 2025 if no due_date is loaded from the autograders file" do
      client.instance_eval { @autograders = {"assignment_one_queue" =>{} } }
      client.send(:load_due_date, "assignment_one_queue").should eq 20250910031500
    end

    it "#load_due_date should load the due date for the part-sid from the autograders file" do

      client.instance_eval { @autograders = {"assignment_one_queue" => {:due => 11111111111} } }
      client.send(:load_due_date, "assignment_one_queue").should eq 11111111111
    end

    it "#load_grace_period should raise an error when called with invalid part-sid" do

        lambda {client.send(:load_grace_period, "nonexistant_sid" )}.should raise_error

    end

    it "#load_grace_period should set a grace_period of '8' if no grace_period is loaded from the autograders file" do
      client.instance_eval { @autograders = {"assignment_one_queue" =>{} } }
      client.send(:load_grace_period, "assignment_one_queue").should eq 8
    end

    it "#load_due_date should for the part-sid from the autograders file" do

      client.instance_eval { @autograders = {"assignment_one_queue" => {:grace_period => '169'} } }
      client.send(:load_grace_period, "assignment_one_queue").should eq 169
    end

    it "#generate_late_response should return the proper scale factors for each late scale" do
      due_date = 20000101010000
                #YYYYMMDDHHMMSS
      grace_period = 1

      correct_results = [
        {:submission_time => due_date, :scale_factor => 1.0},
        {:submission_time => 20000101010300, :scale_factor => 0.75},
        {:submission_time => 20000102010300, :scale_factor => 0.50},
        {:submission_time => 20250101010100, :scale_factor => 0.0}
      ]

      correct_results.each do |scale_info|
        client.send(:generate_late_response, scale_info[:submission_time], due_date, grace_period)[0].should(
          eq scale_info[:scale_factor]
        )

      end
    end

  end

  context "#load_spec" do

    before :each do
    autograders = {
      "autograder1" =>{
        :parts =>{
          "part1" => {
            "uri" => "path/path",
            "type" => "WeightedRspecGrader"
          },
          "part2" => {
            "uri" => "http://fake.false.com",
            "type" => "WeightedRspecGrader"
          },
          "part3" => {
            "uri" => "http://fake.false.com",
            "type" => "WeightedRspecGrader",
            :cache => "fake/path"
          }
        }
      },
      "autograder2" =>{}
    }

    client.instance_eval{@autograders = autograders}
    end

    it "Should raise an error if there is no matching sid found" do
      lambda {client.send(:load_spec, "nonexistant_sid", "part1")}.should raise_error
    end


    it "Should raise an error if there is no matching part found" do
      lambda {client.send(:load_spec, "autograder1", "part_fake")}.should raise_error
    end

    it "Should return the uri and type specified in the autograders variable for a non http uri" do
      client.send(:load_spec, "autograder1", "part1").should eq ["path/path", "WeightedRspecGrader"]
    end

    it "should use the cached path for http specs if the cache is present" do
      client.send(:load_spec, "autograder1", "part3").should eq ["fake/path", "WeightedRspecGrader"]
    end

    context "The spec is not cached" do
      let(:response) { double('response', :code => '200').as_null_object }
      before :each do
        Tempfile.stub(:new).and_return( double('response', :path => 'temp_path').as_null_object )
        Net::HTTP.stub(:get_response).and_return(response)
      end

      it "should make an http request to try to get the new file if the cache is nil" do
        Net::HTTP.should_receive(:get_response)
        client.send(:load_spec, "autograder1", "part2").should eq ["temp_path", "WeightedRspecGrader"]
      end

      it "should raise an error if it can't find the remote spec" do
        response = double('response', :code => '404').as_null_object
        Net::HTTP.stub(:get_response).and_return(response)
        lambda {client.send(:load_spec, "autograder1", "part2") }.should raise_error(EdXClient::SpecNotFound)
      end
    end

  end

  context 'Writing out Student Submissions' do
    before :each do
      #force the client to exist before we stub out the FileSystem
      client
      FakeFS.activate!
    end

    after :each do
      # Purge the log directory after each example
      FileUtils.rm_rf("./log") if File.exists?("./log") and File.directory?("./log")
      FakeFS.deactivate!
    end

    it 'If the /log/ directory does not exist, it should be created' do
      FileUtils.rm_rf("./log") if File.exists?("./log") and File.directory?("./log")
      File.directory?("./log").should_not be_true
      client.send(:write_student_submission, "user_id", "submission content", "assign-1_part-1")
      File.directory?("./log").should be_true
      File.directory?("./log/assign-1_part-1-submissions").should be_true
    end

    it 'If the /log/ directory exist, the files it contains should be persisted' do
      FileUtils.mkdir_p("./log/assign-1_part-1-submissions") if not( File.exists?("./log") and File.directory?("./log") )
      File.directory?("./log/assign-1_part-1-submissions").should be_true

      FileUtils.touch("./log/assign-1_part-1-submissions/user_idfile.txt")
      client.send(:write_student_submission, "user_id", "submission content", "assign-1_part-1")
      File.exists?("./log/assign-1_part-1-submissions/user_idfile.txt").should be_true
    end

    it 'Should create a new file for multiple submissions from the same student ' do

      client.send(:write_student_submission, "user_id", "submission content", "assign-1_part-1")
      client.send(:write_student_submission, "user_id", "submission content", "assign-1_part-1")

      File.exists?("./log/assign-1_part-1-submissions/user_id_attempt_1").should be_true
      File.exists?("./log/assign-1_part-1-submissions/user_id_attempt_2").should be_true

    end
  end

end