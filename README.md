# teeveed

natural language daemon for the media center.

My winter break project (12/28/13 - 1/10/14) by [@jitl](https://twitter.com/@jitl)

## Development

#### Requirements

- Java JDK 1.7
- Maven 2+
- JRuby 1.7.x
- PostgreSQL 9.1+ *with* the `pg_trgm` extension! **pg_trgm** is one
  of the ways we find similar-text matches

teeveed uses [gem-maven-plugin][gem] instead of `Bundler` to manage
requirements. See `pom.xml` for more information.

#### Get Hacking

1. `git clone https://github.com/justjake/teeveed` or similar to get the source
2. `cd teeveed`, `mvn initialize` will download and install the required rubygems
   in `teeveed/target/rubygems`
3. `source env.sh` will correct your `$GEM_HOME` and `$RUBY_LIB` environment variables
   to point to the gems installed in `teeveed/target/rubygems` and the teeveed sources.
4. Hack away. run `teeveed` (alias provided by env.sh) to start the daemon, or
   `cli` to start the Pry command line.

If things feel too slow,
You should get [drip](https://github.com/flatland/drip) in your ~/bin,
and then `source drip.env.sh` before launching any of this ruby junk.
Drip'll put the spring back in your step!

## Installation

#### Requirements

- Java JDK 1.7
- Maven 2+ (for HUD)
- a Postgres database

The only reason we need Maven and the JDK is because (right now)
teeveed isn't packaged as a JavaFX runtime app. Because the JavaFX
runtime does some interesting [native loading things][javafx-oops],
the simplest way is just to move the JavaFX libraries into the
implicit system classpath.

I will get around to fixing this, but it's low priority for my own
machines.

#### Instructions

1. `(sudo) mvn com.zenjava:javafx-maven-plugin:2.0:fix-classpath`

   This moves JavaFX onto the classpath so the JavaFX libraries are
   always loaded. **THIS STEP IS ONLY REQUIRED ON USER-INTERFACE MACHINES**

1.  make a directory for all of the teeveed resources. I like `~/teeveed`.
1.  copy `teeveed-0.2.2.jar` and `example.teeveed.conf.rb` into
    your teeveed folder.
1.  copy `teeveed.sh` into your `~/bin` or somewhere else on your path,
    and modify `$TEEVEED_HOME` in it to point to your teeveed folder.
1.  Create a Postgres database and user for teeveed. Make sure your
    postgres instance is accessable over TCP (unencrypted)
1.  Change `example.teeveed.conf.rb` so that it matches your setup.
    Important things to change:

    - `database` command to match the setup of your Postgres database
    - `library` command's path should be '/path/to/your/media'
    - You'll need to insert your Wit.ai token for the `teeveed` instance

[javafx-oops]: http://zenjava.com/javafx/maven/fix-classpath.html
[gem]: https://github.com/torquebox/jruby-maven-plugins#installing-gems-into-you-project-directory

## Goals

#### Index

- Keep a fast index of all the media on a share for quick search (DONE)
- index needs to respond to natural-language searches (DONE)
    - few spelling mistakes, mostly word transpositions (TODO: switch to trigram)
- deleted items should be pruned regularly (DONE)
- delegte music indexing and search to Spotify (TODO)

##### Strategy

The index is stored in a PostgeSQL database, which gets us nice
full-text-search for free. Indexing is performed by crawling each
library section on a specified schedule, and adding new items, and
removing old items based on a `last_seen` timestamp.

At some point we should use the following algorithm when returning
search results, so that we never return a file that doesn't exist:

```ruby
# Array<Media> returned in ranked order from best to worst match
results = root.search(:title => "the good the bad the ugly", :sense => :watch)
results.each do |hit|
    path = Pathname.new(root.path) + hit.relative_path
    if not path.exist?
        hit.delete!
        next
    end

    path = path.realpath.to_s
    return Result.new(hit, path)
end
```

#### Natural Language Interface

- User story: you sit down on the couch and say,
  "Ok tv. do we have the new Game of Thrones?"

- User story: you want to quickly start music playing while
  in the kitchen. "Ok tv. Play songs by Royksopp"

We use [**Wit.ai**](http://wit.ai) to interpret user intents from plain
text. Intent behavior is defined in `lib/teevee/daemon/intent_controller.rb`,
which performs dispatch based on intent type.

#### Visual indicators (DONE)

teeveed uses a simple JavaFX window to display user intents and
matched entities on-screen. All intents are automatically
displayed before they are handled, and the results of the handler
(anything with a :friendly_name) function are displayed when the
handler completes.

