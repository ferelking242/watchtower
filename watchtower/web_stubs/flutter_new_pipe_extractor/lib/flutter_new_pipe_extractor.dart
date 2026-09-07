class MediaFormat {
    final String mimeType;
    const MediaFormat(this.mimeType);
  }

  class UploadDate {
    final DateTime offsetDateTime;
    const UploadDate(this.offsetDateTime);
  }

  class StreamDescription {
    final String? content;
    const StreamDescription(this.content);
  }

  class StreamType {
    final String name;
    const StreamType(this.name);
    static const live = StreamType('live');
    static const videoStream = StreamType('videoStream');
    static const audioStream = StreamType('audioStream');
  }

  class AudioStream {
    final int itag;
    final String content;
    final int bitrate;
    final String codec;
    final MediaFormat? mediaFormat;
    const AudioStream({required this.itag, required this.content, required this.bitrate, this.codec = '', this.mediaFormat});
  }

  class VideoStream {
    final int itag;
    final String content;
    final int bitrate;
    final String codec;
    final MediaFormat? mediaFormat;
    const VideoStream({required this.itag, required this.content, required this.bitrate, this.codec = '', this.mediaFormat});
  }

  class VideoInfo {
    final String id;
    final String name;
    final String uploaderName;
    final String uploaderUrl;
    final UploadDate uploadDate;
    final StreamDescription description;
    final int duration;
    final int viewCount;
    final int? likeCount;
    final int? dislikeCount;
    final List<String> tags;
    final StreamType streamType;
    final List<AudioStream> audioStreams;
    final List<VideoStream> videoStreams;
    const VideoInfo({
      required this.id, required this.name, required this.uploaderName,
      required this.uploaderUrl, required this.uploadDate, required this.description,
      required this.duration, required this.viewCount, this.likeCount, this.dislikeCount,
      this.tags = const [], required this.streamType,
      this.audioStreams = const [], this.videoStreams = const [],
    });
  }

  class VideoSearchResultItem {
    final String url;
    final String name;
    final String uploaderName;
    final String uploaderUrl;
    final UploadDate? uploadDate;
    final String? shortDescription;
    final int duration;
    final int viewCount;
    final StreamType streamType;
    const VideoSearchResultItem({
      required this.url, required this.name, required this.uploaderName,
      required this.uploaderUrl, this.uploadDate, this.shortDescription,
      required this.duration, required this.viewCount, required this.streamType,
    });
  }

  class Engagement {
    final int viewCount;
    final int? likeCount;
    final int? dislikeCount;
    const Engagement(this.viewCount, this.likeCount, this.dislikeCount);
  }

  enum SearchContentFilters { videos, channels, playlists }

  class NewPipeExtractor {
    static Future<dynamic> getStream(String url) async => null;
    static Future<List<dynamic>> getRelatedStreams(String url) async => [];
    static Future<VideoInfo> getVideoInfo(String videoId) async =>
        throw UnimplementedError('NewPipeExtractor not available on web');
    static Future<List<dynamic>> search(String query, {List<SearchContentFilters> contentFilters = const []}) async => [];
    static Future<List<dynamic>> getChannelVideos(String channelUrl) async => [];
  }
  