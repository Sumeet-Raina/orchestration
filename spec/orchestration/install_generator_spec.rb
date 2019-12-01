# frozen_string_literal: true

RSpec.describe Orchestration::InstallGenerator do
  subject(:install_generator) { described_class.new }

  it { is_expected.to be_a described_class }

  let(:dummy_path) { Orchestration.root.join('spec', 'dummy') }
  let(:orchestration_path) { dummy_path.join('orchestration') }

  it 'creates yaml.bash' do
    path = orchestration_path.join('yaml.bash')
    FileUtils.rm_f(path)
    install_generator.yaml_bash
    expect(File).to exist(path)
  end

  it 'creates deploy.mk' do
    path = orchestration_path.join('deploy.mk')
    FileUtils.rm_f(path)
    install_generator.deploy_mk
    expect(File).to exist(path)
  end

  it 'creates .env' do
    path = dummy_path.join('.env')
    FileUtils.rm_f(path)
    install_generator.env
    expect(File).to exist(path)
  end

  it 'does not overwrite .env' do
    path = dummy_path.join('.env')
    File.write(path, 'some env settings')
    install_generator.env
    expect(File.read(path)).to eql 'some env settings'
  end
end
