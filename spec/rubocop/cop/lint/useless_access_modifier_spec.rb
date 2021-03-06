# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Lint::UselessAccessModifier do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  context 'when an access modifier has no effect' do
    it 'registers an offense' do
      expect_offense(<<-RUBY.strip_indent)
        class SomeClass
          def some_method
            puts 10
          end
          private
          ^^^^^^^ Useless `private` access modifier.
          def self.some_method
            puts 10
          end
        end
      RUBY
    end
  end

  context 'when an access modifier has no methods' do
    it 'registers an offense' do
      expect_offense(<<-RUBY.strip_indent)
        class SomeClass
          def some_method
            puts 10
          end
          protected
          ^^^^^^^^^ Useless `protected` access modifier.
        end
      RUBY
    end
  end

  context 'when an access modifier is followed by attr_*' do
    it 'does not register an offense' do
      expect_no_offenses(<<-RUBY.strip_indent)
        class SomeClass
          protected
          attr_accessor :some_property
          public
          attr_reader :another_one
          private
          attr :yet_again, true
          protected
          attr_writer :just_for_good_measure
        end
      RUBY
    end
  end

  context 'when an access modifier is followed by a ' \
    'class method defined on constant' do

    it 'registers an offense' do
      expect_offense(<<-RUBY.strip_indent)
        class SomeClass
          protected
          ^^^^^^^^^ Useless `protected` access modifier.
          def SomeClass.some_method
          end
        end
      RUBY
    end
  end

  context 'when there are consecutive access modifiers' do
    it 'registers an offense' do
      expect_offense(<<-RUBY.strip_indent)
        class SomeClass
         private
         private
         ^^^^^^^ Useless `private` access modifier.
          def some_method
            puts 10
          end
          def some_other_method
            puts 10
          end
        end
      RUBY
    end
  end

  context 'when passing method as symbol' do
    it 'does not register an offense' do
      expect_no_offenses(<<-RUBY.strip_indent)
        class SomeClass
          def some_method
            puts 10
          end
          private :some_method
        end
      RUBY
    end
  end

  context 'when class is empty save modifier' do
    it 'registers an offense' do
      expect_offense(<<-RUBY.strip_indent)
        class SomeClass
          private
          ^^^^^^^ Useless `private` access modifier.
        end
      RUBY
    end
  end

  context 'when multiple class definitions in file but only one has offense' do
    it 'registers an offense' do
      expect_offense(<<-RUBY.strip_indent)
        class SomeClass
          private
          ^^^^^^^ Useless `private` access modifier.
        end
        class SomeOtherClass
        end
      RUBY
    end
  end

  if RUBY_ENGINE == 'ruby' && RUBY_VERSION.start_with?('2.1')
    context 'ruby 2.1 style modifiers' do
      it 'does not register an offense' do
        expect_no_offenses(<<-RUBY.strip_indent)
          class SomeClass
            private def some_method
              puts 10
            end
          end
        RUBY
      end
    end
  end

  context 'when only a constant or local variable is defined after the ' \
    'modifier' do
    %w[CONSTANT some_var].each do |binding_name|
      it 'registers an offense' do
        expect_offense(<<-RUBY.strip_indent)
          class SomeClass
            private
            ^^^^^^^ Useless `private` access modifier.
            #{binding_name} = 1
          end
        RUBY
      end
    end
  end

  context 'when a def is an argument to a method call' do
    it 'does not register an offense' do
      expect_no_offenses(<<-RUBY.strip_indent)
        class SomeClass
          private
          helper_method def some_method
            puts 10
          end
        end
      RUBY
    end
  end

  context "when using ActiveSupport's `concerning` method" do
    let(:config) do
      RuboCop::Config.new(
        'Lint/UselessAccessModifier' => {
          'ContextCreatingMethods' => ['concerning']
        }
      )
    end

    it 'is aware that this creates a new scope' do
      expect_no_offenses(<<-RUBY.strip_indent)
        class SomeClass
          concerning :FirstThing do
            def foo
            end
            private

            def method
            end
          end

          concerning :SecondThing do
            def omg
            end
            private
            def method
            end
          end
         end
      RUBY
    end

    it 'still points out redundant uses within the block' do
      expect_offense(<<-RUBY.strip_indent)
        class SomeClass
          concerning :FirstThing do
            def foo
            end
            private

            def method
            end
          end

          concerning :SecondThing do
            def omg
            end
            private
            def method
            end
            private
            ^^^^^^^ Useless `private` access modifier.
            def another_method
            end
          end
         end
      RUBY
    end
  end

  context 'when using ActiveSupport behavior when Rails is not eabled' do
    it 'reports offenses' do
      expect_offense(<<-RUBY.strip_indent)
        module SomeModule
          extend ActiveSupport::Concern
          class_methods do
            def some_public_class_method
            end
            private
            def some_private_class_method
            end
          end
          def some_public_instance_method
          end
          private
          ^^^^^^^ Useless `private` access modifier.
          def some_private_instance_method
          end
        end
      RUBY
    end
  end

  context 'when using the class_methods method from ActiveSupport::Concern' do
    let(:config) do
      RuboCop::Config.new(
        'Lint/UselessAccessModifier' => {
          'ContextCreatingMethods' => ['class_methods']
        }
      )
    end

    it 'is aware that this creates a new scope' do
      expect_no_offenses(<<-RUBY.strip_indent)
        module SomeModule
          extend ActiveSupport::Concern
          class_methods do
            def some_public_class_method
            end
            private
            def some_private_class_method
            end
          end
          def some_public_instance_method
          end
          private
          def some_private_instance_method
          end
        end
      RUBY
    end
  end

  context 'when using a known method-creating method' do
    let(:config) do
      RuboCop::Config.new(
        'Lint/UselessAccessModifier' => {
          'MethodCreatingMethods' => ['delegate']
        }
      )
    end

    it 'is aware that this creates a new method' do
      expect_no_offenses(<<-RUBY.strip_indent)
        class SomeClass
          private

          delegate :foo, to: :bar
        end
      RUBY
    end

    it 'still points out redundant uses within the module' do
      expect_offense(<<-RUBY.strip_indent)
        class SomeClass
          delegate :foo, to: :bar

          private
          ^^^^^^^ Useless `private` access modifier.
        end
      RUBY
    end
  end

  shared_examples 'at the top of the body' do |keyword|
    it 'registers an offense for `public`' do
      src = <<-RUBY.strip_indent
        #{keyword} A
          public
          def method
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.size).to eq(1)
    end

    it "doesn't register an offense for `protected`" do
      src = <<-RUBY.strip_indent
        #{keyword} A
          protected
          def method
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.empty?).to be(true)
    end

    it "doesn't register an offense for `private`" do
      src = <<-RUBY.strip_indent
        #{keyword} A
          private
          def method
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.empty?).to be(true)
    end
  end

  shared_examples 'repeated visibility modifiers' do |keyword, modifier|
    it "registers an offense when `#{modifier}` is repeated" do
      src = <<-RUBY.strip_indent
        #{keyword} A
          #{modifier == 'private' ? 'protected' : 'private'}
          def method1
          end
          #{modifier}
          #{modifier}
          def method2
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.size).to eq(1)
    end
  end

  shared_examples 'non-repeated visibility modifiers' do |keyword|
    it 'registers an offense even when `public` is not repeated' do
      src = <<-RUBY.strip_indent
        #{keyword} A
          def method1
          end
          public
          def method2
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.size).to eq(1)
    end

    it "doesn't register an offense when `protected` is not repeated" do
      src = <<-RUBY.strip_indent
        #{keyword} A
          def method1
          end
          protected
          def method2
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.empty?).to be(true)
    end

    it "doesn't register an offense when `private` is not repeated" do
      src = <<-RUBY.strip_indent
        #{keyword} A
          def method1
          end
          private
          def method2
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.empty?).to be(true)
    end
  end

  shared_examples 'at the end of the body' do |keyword, modifier|
    it "registers an offense for trailing `#{modifier}`" do
      src = <<-RUBY.strip_indent
        #{keyword} A
          def method1
          end
          def method2
          end
          #{modifier}
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.size).to eq(1)
    end
  end

  shared_examples 'nested in a begin..end block' do |keyword, modifier|
    it "still flags repeated `#{modifier}`" do
      src = <<-RUBY.strip_indent
        #{keyword} A
          #{modifier == 'private' ? 'protected' : 'private'}
          def blah
          end
          begin
            def method1
            end
            #{modifier}
            #{modifier}
            def method2
            end
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.size).to eq(1)
    end

    unless modifier == 'public'
      it "doesn't flag an access modifier from surrounding scope" do
        src = <<-RUBY.strip_indent
          #{keyword} A
            #{modifier}
            begin
              def method1
              end
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.empty?).to be(true)
      end
    end
  end

  shared_examples 'unused visibility modifiers' do |keyword|
    it 'registers an error when visibility is immediately changed ' \
       'without any intervening defs' do
      src = <<-RUBY.strip_indent
        #{keyword} A
          private
          def method1
          end
          public # bad
          private
          def method2
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.size).to eq(1)
    end
  end

  shared_examples 'conditionally defined method' do |keyword, modifier|
    %w[if unless].each do |conditional_type|
      it "doesn't register an offense for #{conditional_type}" do
        src = <<-RUBY.strip_indent
          #{keyword} A
            #{modifier}
            #{conditional_type} x
              def method1
              end
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.empty?).to be(true)
      end
    end
  end

  shared_examples 'methods defined in an iteration' do |keyword, modifier|
    %w[each map].each do |iteration_method|
      it "doesn't register an offense for #{iteration_method}" do
        src = ["#{keyword} A",
               "  #{modifier}",
               "  [1, 2].#{iteration_method} do |i|",
               '    define_method("method#{i}") do',
               '      i',
               '    end',
               '  end',
               'end']
        inspect_source(src)
        expect(cop.offenses.empty?).to be(true)
      end
    end
  end

  shared_examples 'method defined with define_method' do |keyword, modifier|
    it "doesn't register an offense if a block is passed" do
      src = <<-RUBY.strip_indent
        #{keyword} A
          #{modifier}
          define_method(:method1) do
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.empty?).to be(true)
    end

    %w[lambda proc ->].each do |proc_type|
      it "doesn't register an offense if a #{proc_type} is passed" do
        src = <<-RUBY.strip_indent
          #{keyword} A
            #{modifier}
            define_method(:method1, #{proc_type} { })
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.empty?).to be(true)
      end
    end
  end

  shared_examples 'method defined on a singleton class' do |keyword, modifier|
    context 'inside a class' do
      it "doesn't register an offense if a method is defined" do
        src = <<-RUBY.strip_indent
          #{keyword} A
            class << self
              #{modifier}
              define_method(:method1) do
              end
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.empty?).to be(true)
      end

      it "doesn't register an offense if the modifier is the same as " \
        'outside the meta-class' do
        src = <<-RUBY.strip_indent
          #{keyword} A
            #{modifier}
            def method1
            end
            class << self
              #{modifier}
              def method2
              end
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.empty?).to be(true)
      end

      it 'registers an offense if no method is defined' do
        src = <<-RUBY.strip_indent
          #{keyword} A
            class << self
              #{modifier}
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(1)
      end

      it 'registers an offense if no method is defined after the modifier' do
        src = <<-RUBY.strip_indent
          #{keyword} A
            class << self
              def method1
              end
              #{modifier}
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(1)
      end

      it 'registers an offense even if a non-singleton-class method is ' \
        'defined' do
        src = <<-RUBY.strip_indent
          #{keyword} A
            def method1
            end
            class << self
              #{modifier}
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(1)
      end
    end

    context 'outside a class' do
      it "doesn't register an offense if a method is defined" do
        src = <<-RUBY.strip_indent
          class << A
            #{modifier}
            define_method(:method1) do
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.empty?).to be(true)
      end

      it 'registers an offense if no method is defined' do
        src = <<-RUBY.strip_indent
          class << A
            #{modifier}
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(1)
      end

      it 'registers an offense if no method is defined after the modifier' do
        src = <<-RUBY.strip_indent
          class << A
            def method1
            end
            #{modifier}
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(1)
      end
    end
  end

  shared_examples 'method defined using class_eval' do |modifier|
    it "doesn't register an offense if a method is defined" do
      src = <<-RUBY.strip_indent
        A.class_eval do
          #{modifier}
          define_method(:method1) do
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.empty?).to be(true)
    end

    it 'registers an offense if no method is defined' do
      src = <<-RUBY.strip_indent
        A.class_eval do
          #{modifier}
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.size).to eq(1)
    end

    context 'inside a class' do
      it 'registers an offense when a modifier is ouside the block and a ' \
        'method is defined only inside the block' do
        src = <<-RUBY.strip_indent
          class A
            #{modifier}
            A.class_eval do
              def method1
              end
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(1)
      end

      it 'registers two offenses when a modifier is inside and outside the ' \
        ' and no method is defined' do
        src = <<-RUBY.strip_indent
          class A
            #{modifier}
            A.class_eval do
              #{modifier}
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(2)
      end
    end
  end

  shared_examples 'def in new block' do |klass, modifier|
    it "doesn't register an offense if a method is defined in #{klass}.new" do
      src = <<-RUBY.strip_indent
        #{klass}.new do
          #{modifier}
          def foo
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.empty?).to be(true)
    end

    it "registers an offense if no method is defined in #{klass}.new" do
      src = <<-RUBY.strip_indent
        #{klass}.new do
          #{modifier}
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.size).to eq(1)
    end
  end

  shared_examples 'method defined using instance_eval' do |modifier|
    it "doesn't register an offense if a method is defined" do
      src = <<-RUBY.strip_indent
        A.instance_eval do
          #{modifier}
          define_method(:method1) do
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.empty?).to be(true)
    end

    it 'registers an offense if no method is defined' do
      src = <<-RUBY.strip_indent
        A.instance_eval do
          #{modifier}
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.size).to eq(1)
    end

    context 'inside a class' do
      it 'registers an offense when a modifier is ouside the block and a ' \
        'method is defined only inside the block' do
        src = <<-RUBY.strip_indent
          class A
            #{modifier}
            self.instance_eval do
              def method1
              end
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(1)
      end

      it 'registers two offenses when a modifier is inside and outside the ' \
        ' and no method is defined' do
        src = <<-RUBY.strip_indent
          class A
            #{modifier}
            self.instance_eval do
              #{modifier}
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(2)
      end
    end
  end

  shared_examples 'nested modules' do |keyword, modifier|
    it "doesn't register an offense for nested #{keyword}s" do
      src = <<-RUBY.strip_indent
        #{keyword} A
          #{modifier}
          def method1
          end
          #{keyword} B
            def method2
            end
            #{modifier}
            def method3
            end
          end
        end
      RUBY
      inspect_source(src)
      expect(cop.offenses.empty?).to be(true)
    end

    context 'unused modifiers' do
      it "registers an offense with a nested #{keyword}" do
        src = <<-RUBY.strip_indent
          #{keyword} A
            #{modifier}
            #{keyword} B
              #{modifier}
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(2)
      end

      it "registers an offense when outside a nested #{keyword}" do
        src = <<-RUBY.strip_indent
          #{keyword} A
            #{modifier}
            #{keyword} B
              def method1
              end
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(1)
      end

      it "registers an offense when inside a nested #{keyword}" do
        src = <<-RUBY.strip_indent
          #{keyword} A
            #{keyword} B
              #{modifier}
            end
          end
        RUBY
        inspect_source(src)
        expect(cop.offenses.size).to eq(1)
      end
    end
  end

  %w[protected private].each do |modifier|
    it_behaves_like('method defined using class_eval', modifier)
    it_behaves_like('method defined using instance_eval', modifier)
  end

  %w[Class Module Struct].each do |klass|
    %w[protected private].each do |modifier|
      it_behaves_like('def in new block', klass, modifier)
    end
  end

  %w[module class].each do |keyword|
    it_behaves_like('at the top of the body', keyword)
    it_behaves_like('non-repeated visibility modifiers', keyword)
    it_behaves_like('unused visibility modifiers', keyword)

    %w[public protected private].each do |modifier|
      it_behaves_like('repeated visibility modifiers', keyword, modifier)
      it_behaves_like('at the end of the body', keyword, modifier)
      it_behaves_like('nested in a begin..end block', keyword, modifier)

      next if modifier == 'public'

      it_behaves_like('conditionally defined method', keyword, modifier)
      it_behaves_like('methods defined in an iteration', keyword, modifier)
      it_behaves_like('method defined with define_method', keyword, modifier)
      it_behaves_like('method defined on a singleton class', keyword, modifier)
      it_behaves_like('nested modules', keyword, modifier)
    end
  end
end
