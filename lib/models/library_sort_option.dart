import 'tree_build.dart';

enum LibrarySortOption {
  alphabetical,
  reverseAlphabetical,
  newest,
  oldest;

  String get label {
    switch (this) {
      case LibrarySortOption.alphabetical:
        return 'A → Z';
      case LibrarySortOption.reverseAlphabetical:
        return 'Z → A';
      case LibrarySortOption.newest:
        return 'Newest first';
      case LibrarySortOption.oldest:
        return 'Oldest first';
    }
  }
}

List<TreeBuild> sortTreeBuilds(
  List<TreeBuild> builds,
  LibrarySortOption option,
) {
  final copy = List<TreeBuild>.from(builds);
  switch (option) {
    case LibrarySortOption.alphabetical:
      copy.sort(
        (a, b) =>
            a.rootName.toLowerCase().compareTo(b.rootName.toLowerCase()),
      );
    case LibrarySortOption.reverseAlphabetical:
      copy.sort(
        (a, b) =>
            b.rootName.toLowerCase().compareTo(a.rootName.toLowerCase()),
      );
    case LibrarySortOption.newest:
      copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case LibrarySortOption.oldest:
      copy.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  return copy;
}
