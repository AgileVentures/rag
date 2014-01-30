require 'spec_helper'

describe 'grader3' do
  let(:grader) { 'grade3' }

  before(:each) do
    @reference_application_folder = File.expand_path('test.app')
    @feature_file = File.expand_path('test.feature')
    @config_file = File.expand_path('test.yml')
    ARGV.replace %W(-a #{@reference_application_folder} test.feature test.yml)

    @auto_grader = double(AutoGrader).as_null_object
    AutoGrader.stub(:create).and_return(@auto_grader)

    Dir.stub(:chdir)
    Dir.stub(:getwd).and_return(@reference_application_folder)
  end

  describe 'validating command line invocation' do
    it 'prints out usage information when no parameters are passed' do
      output = `./#{grader}`
      expect(output).to include('Usage:')
    end
    it 'prints out usage information when wrong number parameters are passed' do
      output = `./#{grader} -a Test Test`
      expect(output).to include('Usage:')
    end

    it 'prints out usage information when reference application path is not passed' do
      output = `./#{grader} test.app test.feature test.yml`
      expect(output).to include('Usage:')
    end
  end
  describe 'setting environment' do
    it 'changes the working directory to the reference application root' do
      expect(Dir).to receive(:chdir).with(@reference_application_folder)
      load grader
    end
    it 'sets the environment variable RAILS_ROOT to reference_application_root' do
      load grader
      expect(ENV['RAILS_ROOT']).to eq(@reference_application_folder)
    end
    it 'initializes AutoGrader with correct parameters' do
      expect(AutoGrader).to receive(:create) do |arg_1, arg_2, arg_3, arg_4|
        expect(arg_1).to eq('3')
        expect(arg_2).to eq('HW3Grader')
        expect(arg_3).to eq(@feature_file)
        expect(arg_4[:description]).to eq(@config_file)
        @auto_grader # return @autograder double defined in before(:each) block
      end
      load grader
    end
  end
  describe 'running AutoGrader' do
    it 'runs AutoGrader' do
      expect(@auto_grader).to receive(:grade!)
      load grader
    end

    it 'raises an error if an AutoGrader fails' do
      mock_stderr = StringIO.new
      $stderr = mock_stderr
      expect(@auto_grader).to respond_to
      AutoGrader.stub(:create).and_call_original
      expect { load grader }.to raise_error
      expect(mock_stderr.string).to include('FATAL')
    end
    it 'prints out the score and comments' do
      mock_stdout = StringIO.new
      $stdout = mock_stdout
      @auto_grader.stub(:normalized_score).and_return(1000)

      load grader
      expect(mock_stdout.string).to include('Score out of', '1000', 'BEGIN', 'END')
    end
  end
end
