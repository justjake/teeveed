# teeveed

natural language daemon for the media center

winter break project 12/28/13 - 1/10/14 by @jitl

## development

everything in jruby in 2.0.0 mode. usual setup with Bundler.
at some point PostgreSQL will be required.

TODO: tests or something

## Goals

### Index

- Keep a fast index of all the media on a share for quick search
- index needs to respond to natural-language searches
    - few spelling mistakes, mostly word transpositions
- deleted items should be pruned regularly
- delegte music indexing and search to Spotify

#### Strategy

*DataMapper + Postgres + Listen* for indexing a media library and extracting
rudamentry element information from pathnames

On indexer startup, the index database is rebuilt from scratch, to eliminate
stale indexes. This is fine to do, as
`time find /mnt/storage/{Movies,Television,Books} > /dev/null` shows that
crawling these directories won't be too slow.

In addition to rebuilding the index on application boot, all index queries will
have the following protection run on them (idealized implementation)

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

### Natural Language Interface

- User story: you sit down on the couch and say,
  "Ok tv. do we have the new Game of Thrones?"

- User story: you want to quickly start music playing while
  in the kitchen. "Ok tv. Play songs by Royksopp"

#### Strategy

*Wit.ai + Faraday* to detect user intents.
*Sinatra* to serve a basic website for user input from mobile devices.

### Visual indicators (planned)

We need some way to acknoledge user actions quickly on the TV itself.
This is important when you're sitting there waiting for an action to be taken.
We need to know the confidence level of wit.ai, the selected intent,
the detected parameters, and the commands that `teeveed` will run on our behalf

#### Strategy

*Processing* in Java to show user intents and actions taken on-screen
