package org.teton_landis.jake.teeveed;

import java.util.Map;

/**
 * Represends a single media file as a link to a SearchDirectory,
 * a relative path from that SearchDir on disk, and a map of
 * metadata descriptors.
 *
 * in org.teton_landis.jake.teeveed
 *
 * @author jitl
 * @date 3/24/14
 */
public class MediaFile {
  public String relativePath;
  public SearchDirectory searchDir;
  public Map<String, String> metadata;
}
