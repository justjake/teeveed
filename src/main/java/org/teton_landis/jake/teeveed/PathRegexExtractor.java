package org.teton_landis.jake.teeveed;

import java.util.*;
import java.util.regex.*;
import com.google.common.collect.Lists;
import com.google.common.collect.Maps;
import com.google.common.collect.Sets;

/**
 * The PathRegexExtractor finds metadata from only a file's path. This is intended
 * to replace the behavior of Teevee::Library::Media's built-in metadata extraction.
 *
 * in org.teton_landis.jake.teeveed
 *
 * @author jitl
 * @date 3/25/14
 */
public class PathRegexExtractor implements MetadataExtractor {

  private Pattern regex;
  private Set<String> example_paths = new HashSet<String>();
  private Set<String> possible_named_groups;


  public PathRegexExtractor(String regex) {
    this.regex = Pattern.compile(regex);
    possible_named_groups = getNamedGroupCandidates(regex);
  }

  @Override
  public Set<String> possibleFields() {
    Set<String> flat_keys = new HashSet<String>();
    for (String example : example_paths) {
      Map<String, String> res = metadataFor(null, example);
      if (res != null) {
        flat_keys.addAll(res.keySet());
      }
    }
    return flat_keys;
  }

  /**
   * Each instance of a PathRegexExtractor should have a few example paths that its
   * regex can extract metadata from. We run the regex against these paths to discover
   * what metadata names we can return.
   *
   * @param example_relative_path a mock path that we can extract metadata from
   * @return the metadata extracted from that path, or null if it is invalid.
   */
  public Map<String, String> provideExample(String example_relative_path) {
    Map<String, String> matches = metadataFor(null, example_relative_path);
    if (matches == null) {
      return null;
    }

    example_paths.add(example_relative_path);
    return matches;
  }

  @Override
  public Map<String, String> metadataFor(SearchDirectory sd, String abs_path) {
    String relative_path = (sd == null ? abs_path : abs_path.replace(sd.getPath(), ""));
    Matcher matcher = regex.matcher(relative_path);
    Map<String, String> result = new HashMap<String, String>();

    if (! matcher.matches()) { return null; }

    for (String group : possible_named_groups) {
      try {
        result.put(group, matcher.group(group));
      } catch (IllegalArgumentException derp) {
        // nothing -- maybe group wasn't found!
      }
    }

    return result;
  }

  /**
   * because Java doesn't provide an API to get possible named matches from a Pattern,
   * or even the successful named matches from a Matcher, we're left to pull out named
   * groups with a regex of our own!
   * @param regex
   *        find al the named groups in this regex
   * @return names of groups
   */
  private static Set<String> getNamedGroupCandidates(String regex) {
    Set<String> namedGroups = new TreeSet<String>();
    Matcher m = Pattern.compile("\\(\\?<([a-zA-Z][a-zA-Z0-9]*)>").matcher(regex);
    while (m.find()) {
      namedGroups.add(m.group(1));
    }
    return namedGroups;
  }
}
