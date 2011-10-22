require 'spec_helper'

describe 'command line' do
  before :all do
    write_file 'spec/randomize_spec.rb', """
      describe 'group 1' do
        specify('example 1')  { fail }
        specify('example 2')  { fail }
        specify('example 3')  { fail }
        specify('example 4')  { fail }
        specify('example 5')  { fail }
        specify('example 6')  { fail }
        specify('example 7')  { fail }
        specify('example 8')  { fail }
        specify('example 9')  { fail }
        specify('example 10') { fail }
        specify('example 11') { fail }
        specify('example 12') { fail }
        specify('example 13') { fail }
        specify('example 14') { fail }
        specify('example 15') { fail }

        describe 'group 1-1' do
          specify('example 1')  { fail }
          specify('example 2')  { fail }
          specify('example 3')  { fail }
          specify('example 4')  { fail }
          specify('example 5')  { fail }
          specify('example 6')  { fail }
          specify('example 7')  { fail }
          specify('example 8')  { fail }
          specify('example 9')  { fail }
          specify('example 10') { fail }
          specify('example 11') { fail }
          specify('example 12') { fail }
          specify('example 13') { fail }
          specify('example 14') { fail }
          specify('example 15') { fail }

          describe 'group 1-1-1' do
            specify('example 1')  { fail }
            specify('example 2')  { fail }
            specify('example 3')  { fail }
            specify('example 4')  { fail }
            specify('example 5')  { fail }
            specify('example 6')  { fail }
            specify('example 7')  { fail }
            specify('example 8')  { fail }
            specify('example 9')  { fail }
            specify('example 10') { fail }
            specify('example 11') { fail }
            specify('example 11') { fail }
            specify('example 12') { fail }
            specify('example 13') { fail }
            specify('example 14') { fail }
            specify('example 15') { fail }
          end

          describe('group 1-1-2')  { specify('example') { fail } }
          describe('group 1-1-3')  { specify('example') { fail } }
          describe('group 1-1-4')  { specify('example') { fail } }
          describe('group 1-1-5')  { specify('example') { fail } }
          describe('group 1-1-6')  { specify('example') { fail } }
          describe('group 1-1-7')  { specify('example') { fail } }
          describe('group 1-1-8')  { specify('example') { fail } }
          describe('group 1-1-9')  { specify('example') { fail } }
          describe('group 1-1-10') { specify('example') { fail } }
          describe('group 1-1-11') { specify('example') { fail } }
          describe('group 1-1-12') { specify('example') { fail } }
          describe('group 1-1-13') { specify('example') { fail } }
          describe('group 1-1-14') { specify('example') { fail } }
          describe('group 1-1-15') { specify('example') { fail } }
        end

        describe('group 1-2')  { specify('example') { fail } }
        describe('group 1-3')  { specify('example') { fail } }
        describe('group 1-4')  { specify('example') { fail } }
        describe('group 1-5')  { specify('example') { fail } }
        describe('group 1-6')  { specify('example') { fail } }
        describe('group 1-7')  { specify('example') { fail } }
        describe('group 1-8')  { specify('example') { fail } }
        describe('group 1-9')  { specify('example') { fail } }
        describe('group 1-10') { specify('example') { fail } }
        describe('group 1-11') { specify('example') { fail } }
        describe('group 1-12') { specify('example') { fail } }
        describe('group 1-13') { specify('example') { fail } }
        describe('group 1-14') { specify('example') { fail } }
        describe('group 1-15') { specify('example') { fail } }
      end

      describe('group 2')  { specify('example') { fail } }
      describe('group 3')  { specify('example') { fail } }
      describe('group 4')  { specify('example') { fail } }
      describe('group 5')  { specify('example') { fail } }
      describe('group 6')  { specify('example') { fail } }
      describe('group 7')  { specify('example') { fail } }
      describe('group 8')  { specify('example') { fail } }
      describe('group 9')  { specify('example') { fail } }
      describe('group 10') { specify('example') { fail } }
      describe('group 11') { specify('example') { fail } }
      describe('group 12') { specify('example') { fail } }
      describe('group 13') { specify('example') { fail } }
      describe('group 14') { specify('example') { fail } }
      describe('group 15') { specify('example') { fail } }
    """
  end

  def get_failures(number)
    all_stdout.scan(/\s{1}#{number}\).+/).uniq
  end 

  describe '--randomize' do
    it 'runs the example groups and examples in random order' do
      2.times do
        run_simple 'rspec spec/randomize_spec.rb --randomize', false
      end
      
      1.upto(85) do |number|
        get_failures(number).size.should be > 1,
          "Failure messages for ##{number} are the same"
      end

      all_stdout.should match(
        /This run was randomized by the following seed: \d+/
      )
    end

    context 'with --seed' do
      it 'runs the example groups and examples in the same order' do
        2.times do
          run_simple 'rspec spec/randomize_spec.rb --randomize --seed 123', false
        end

        1.upto(85) do |number|
          get_failures(number).size.should eq(1),
            "Failure messages for ##{number} are not the same"
        end

        all_stdout.should match(
          /This run was randomized by the following seed: 123/
        )
      end
    end
  end

  describe '--seed' do
    it 'runs the example groups and examples in the same order' do
      2.times do
        run_simple 'rspec spec/randomize_spec.rb --seed 123', false
      end

      1.upto(85) do |number|
        get_failures(number).size.should eq(1),
          "Failure messages for ##{number} are not the same"
      end

      all_stdout.should match(
        /This run was randomized by the following seed: 123/
      )
    end
  end
end
