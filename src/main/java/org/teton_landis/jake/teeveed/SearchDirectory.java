package org.teton_landis.jake.teeveed;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;

/**
 * A SearchDirectory is a filesystem path where a specific sort of media can
 * be found, and the information to find metadata for that media.
 * Example: /mnt/storage/Moves is a SearchDirectory that contains movies
 */

public class SearchDirectory {
  private File root;
  private MetadataExtractor mde;

  public SearchDirectory(String root_path, MetadataExtractor mde) throws FileNotFoundException {
    File possible_root = new File(root_path);
    if (! (possible_root.exists() && possible_root.isDirectory())) {
      throw new FileNotFoundException(root_path);
    }
    root = possible_root;
    this.mde = mde;
  }

  public String getPath() {
    return root.getAbsolutePath();
  }

  public MetadataExtractor getExtractor() {
    return mde;
  }

  // recurses through join(path, subpath) and finds all the
  // files. files are passed through the mde to produce MediaFiles
  // which are then returned.
  protected List<MediaFile> scan(String subpath) throws FileNotFoundException {
    List<MediaFile> results = new LinkedList<MediaFile>();
    File scanned = new File(root, subpath);
    if (! scanned.exists()) {
      throw new FileNotFoundException(scanned.getAbsolutePath());
    }

    if (scanned.isDirectory()) {
      File[] children = scanned.listFiles();
      if (children == null) { return results; }
      for (File child : children) {
        results.addAll(scan(child.getPath()));
      }
      return results;
    }

    MediaFile media = new MediaFile();
    Map<String, String> metadata = mde.metadataFor(this, subpath);
    // TODO: make sure this is a relative path
    media.relativePath = subpath;
    media.metadata = mde.metadataFor(this, subpath);
    media.searchDir = this;

    results.add(media);
    return results;
  }
}
