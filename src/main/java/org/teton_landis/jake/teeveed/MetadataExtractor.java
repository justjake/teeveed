package org.teton_landis.jake.teeveed;

import java.util.Map;
import java.util.Set;

/**
 * MetadataExtractor
 * given a path to a file, find out any meaningful metadata about that file
 * as a piece of media.
 *
 * in org.teton_landis.jake.teeveed
 *
 * @author jitl
 * @date 3/24/14
 */
public interface MetadataExtractor {
  /**
   * Find the apropriate metadata for a given file
   * @param sd the root directory
   * @param relative_path the relative path to the file
   * @return metadata for the given file
   */
  public Map<String, String> metadataFor(SearchDirectory sd, String relative_path);

  /**
   * Gets all the fields this MetadataExtractor might possibly return
   * @return set of field names
   */
  public Set<String> possibleFields();
}
