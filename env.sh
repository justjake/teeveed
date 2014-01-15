# source when you start development
export PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# export WIT_ACCESS_TOKEN="!token goes here!"

export RUBYLIB="$PROJECT_ROOT/lib"
export GEM_HOME="$PROJECT_ROOT/target/rubygems"
export PATH="$GEM_HOME/bin:$PATH"

alias teeveed="$PROJECT_ROOT/bin/teeveed.rb --config $PROJECT_ROOT/config/test.teeveed.rb"
alias cli="teeveed --cli"

function rebuild {
    pushd $PROJECT_ROOT
    rm -r $PROJECT_ROOT/target/*.jar
    mvn install
    popd
}
