// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get guest => 'Visitante';

  @override
  String get browse => 'Explorar';

  @override
  String get search => 'Buscar';

  @override
  String get library => 'Biblioteca';

  @override
  String get lyrics => 'Letras';

  @override
  String get settings => 'Configurações';

  @override
  String get genre_categories_filter => 'Filtrar categorias ou gêneros...';

  @override
  String get genre => 'Gênero';

  @override
  String get personalized => 'Personalizado';

  @override
  String get featured => 'Destaque';

  @override
  String get new_releases => 'Novos Lançamentos';

  @override
  String get songs => 'Músicas';

  @override
  String playing_track(Object track) {
    return 'Tocando $track';
  }

  @override
  String queue_clear_alert(Object track_length) {
    return 'Isso irá limpar a fila atual. $track_length músicas serão removidas.\nDeseja continuar?';
  }

  @override
  String get load_more => 'Carregar mais';

  @override
  String get playlists => 'Playlists';

  @override
  String get artists => 'Artistas';

  @override
  String get albums => 'Álbuns';

  @override
  String get tracks => 'Faixas';

  @override
  String get downloads => 'Downloads';

  @override
  String get filter_playlists => 'Filtrar suas playlists...';

  @override
  String get liked_tracks => 'Músicas Curtidas';

  @override
  String get liked_tracks_description => 'Todas as suas músicas curtidas';

  @override
  String get playlist => 'Playlist';

  @override
  String get create_a_playlist => 'Criar uma playlist';

  @override
  String get update_playlist => 'Atualizar lista de reprodução';

  @override
  String get create => 'Criar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get update => 'Atualizar';

  @override
  String get playlist_name => 'Nome da Playlist';

  @override
  String get name_of_playlist => 'Nome da playlist';

  @override
  String get description => 'Descrição';

  @override
  String get public => 'Pública';

  @override
  String get collaborative => 'Colaborativa';

  @override
  String get search_local_tracks => 'Buscar músicas locais...';

  @override
  String get play => 'Reproduzir';

  @override
  String get delete => 'Excluir';

  @override
  String get none => 'Nenhum';

  @override
  String get sort_a_z => 'Ordenar de A-Z';

  @override
  String get sort_z_a => 'Ordenar de Z-A';

  @override
  String get sort_artist => 'Ordenar por Artista';

  @override
  String get sort_album => 'Ordenar por Álbum';

  @override
  String get sort_duration => 'Ordenar por Duração';

  @override
  String get sort_tracks => 'Ordenar Faixas';

  @override
  String currently_downloading(Object tracks_length) {
    return 'Baixando no momento ($tracks_length)';
  }

  @override
  String get cancel_all => 'Cancelar Tudo';

  @override
  String get refresh => 'Refresh';

  @override
  String get filter_artist => 'Filtrar artistas...';

  @override
  String followers(Object followers) {
    return '$followers Seguidores';
  }

  @override
  String get add_artist_to_blacklist => 'Adicionar artista à lista negra';

  @override
  String get top_tracks => 'Principais Músicas';

  @override
  String get fans_also_like => 'Fãs também curtiram';

  @override
  String get loading => 'Carregando...';

  @override
  String get artist => 'Artista';

  @override
  String get blacklisted => 'Na Lista Negra';

  @override
  String get following => 'Seguindo';

  @override
  String get follow => 'Seguir';

  @override
  String get artist_url_copied =>
      'URL do artista copiada para a área de transferência';

  @override
  String added_to_queue(Object tracks) {
    return 'Adicionadas $tracks músicas à fila';
  }

  @override
  String get filter_albums => 'Filtrar álbuns...';

  @override
  String get synced => 'Sincronizado';

  @override
  String get plain => 'Simples';

  @override
  String get shuffle => 'Aleatório';

  @override
  String get search_tracks => 'Buscar músicas...';

  @override
  String get released => 'Lançado';

  @override
  String error(Object error) {
    return 'Erro $error';
  }

  @override
  String get title => 'Título';

  @override
  String get time => 'Tempo';

  @override
  String get more_actions => 'Mais ações';

  @override
  String download_count(Object count) {
    return 'Baixar ($count)';
  }

  @override
  String add_count_to_playlist(Object count) {
    return 'Adicionar ($count) à Playlist';
  }

  @override
  String add_count_to_queue(Object count) {
    return 'Adicionar ($count) à Fila';
  }

  @override
  String play_count_next(Object count) {
    return 'Reproduzir ($count) em seguida';
  }

  @override
  String get album => 'Álbum';

  @override
  String copied_to_clipboard(Object data) {
    return '$data copiado para a área de transferência';
  }

  @override
  String add_to_following_playlists(Object track) {
    return 'Adicionar $track às Playlists Seguintes';
  }

  @override
  String get add => 'Adicionar';

  @override
  String added_track_to_queue(Object track) {
    return 'Adicionada $track à fila';
  }

  @override
  String get add_to_queue => 'Adicionar à fila';

  @override
  String track_will_play_next(Object track) {
    return '$track será reproduzida em seguida';
  }

  @override
  String get play_next => 'Reproduzir em seguida';

  @override
  String removed_track_from_queue(Object track) {
    return '$track removida da fila';
  }

  @override
  String get remove_from_queue => 'Remover da fila';

  @override
  String get remove_from_favorites => 'Remover dos favoritos';

  @override
  String get save_as_favorite => 'Salvar como favorita';

  @override
  String get add_to_playlist => 'Adicionar à playlist';

  @override
  String get remove_from_playlist => 'Remover da playlist';

  @override
  String get add_to_blacklist => 'Adicionar à lista negra';

  @override
  String get remove_from_blacklist => 'Remover da lista negra';

  @override
  String get share => 'Compartilhar';

  @override
  String get mini_player => 'Mini Player';

  @override
  String get slide_to_seek => 'Arraste para avançar ou retroceder';

  @override
  String get shuffle_playlist => 'Embaralhar playlist';

  @override
  String get unshuffle_playlist => 'Desembaralhar playlist';

  @override
  String get previous_track => 'Faixa anterior';

  @override
  String get next_track => 'Próxima faixa';

  @override
  String get pause_playback => 'Pausar Reprodução';

  @override
  String get resume_playback => 'Continuar Reprodução';

  @override
  String get loop_track => 'Repetir faixa';

  @override
  String get no_loop => 'Sem loop';

  @override
  String get repeat_playlist => 'Repetir playlist';

  @override
  String get queue => 'Fila';

  @override
  String get alternative_track_sources => 'Fontes alternativas de faixas';

  @override
  String get download_track => 'Baixar faixa';

  @override
  String tracks_in_queue(Object tracks) {
    return '$tracks músicas na fila';
  }

  @override
  String get clear_all => 'Limpar tudo';

  @override
  String get show_hide_ui_on_hover => 'Mostrar/Ocultar UI ao passar o mouse';

  @override
  String get always_on_top => 'Sempre no topo';

  @override
  String get exit_mini_player => 'Sair do Mini player';

  @override
  String get download_location => 'Local de download';

  @override
  String get local_library => 'Biblioteca local';

  @override
  String get add_library_location => 'Adicionar à biblioteca';

  @override
  String get remove_library_location => 'Remover da biblioteca';

  @override
  String get account => 'Conta';

  @override
  String get logout => 'Sair';

  @override
  String get logout_of_this_account => 'Sair desta conta';

  @override
  String get language_region => 'Idioma e Região';

  @override
  String get language => 'Idioma';

  @override
  String get system_default => 'Padrão do Sistema';

  @override
  String get market_place_region => 'Região da Loja';

  @override
  String get recommendation_country => 'País de Recomendação';

  @override
  String get appearance => 'Aparência';

  @override
  String get layout_mode => 'Modo de Layout';

  @override
  String get override_layout_settings =>
      'Substituir configurações do modo de layout responsivo';

  @override
  String get adaptive => 'Adaptável';

  @override
  String get compact => 'Compacto';

  @override
  String get extended => 'Estendido';

  @override
  String get theme => 'Tema';

  @override
  String get dark => 'Escuro';

  @override
  String get light => 'Claro';

  @override
  String get system => 'Sistema';

  @override
  String get accent_color => 'Cor de Destaque';

  @override
  String get sync_album_color => 'Sincronizar cor do álbum';

  @override
  String get sync_album_color_description =>
      'Usa a cor predominante da capa do álbum como cor de destaque';

  @override
  String get playback => 'Reprodução';

  @override
  String get audio_quality => 'Qualidade do Áudio';

  @override
  String get high => 'Alta';

  @override
  String get low => 'Baixa';

  @override
  String get pre_download_play => 'Pré-download e reprodução';

  @override
  String get pre_download_play_description =>
      'Em vez de transmitir áudio, baixar bytes e reproduzir (recomendado para usuários com maior largura de banda)';

  @override
  String get skip_non_music => 'Pular segmentos não musicais (SponsorBlock)';

  @override
  String get blacklist_description => 'Faixas e artistas na lista negra';

  @override
  String get wait_for_download_to_finish =>
      'Aguarde o download atual ser concluído';

  @override
  String get desktop => 'Desktop';

  @override
  String get close_behavior => 'Comportamento de Fechamento';

  @override
  String get close => 'Fechar';

  @override
  String get minimize_to_tray => 'Minimizar para a bandeja';

  @override
  String get show_tray_icon => 'Mostrar ícone na bandeja do sistema';

  @override
  String get about => 'Sobre';

  @override
  String get u_love_spotube => 'Sabemos que você adora o Spotube';

  @override
  String get check_for_updates => 'Verificar atualizações';

  @override
  String get about_spotube => 'Sobre o Spotube';

  @override
  String get blacklist => 'Lista Negra';

  @override
  String get please_sponsor => 'Por favor, patrocine/doe';

  @override
  String get spotube_description =>
      'Spotube, um cliente leve, multiplataforma e gratuito para o Spotify';

  @override
  String get version => 'Versão';

  @override
  String get build_number => 'Número de Build';

  @override
  String get founder => 'Fundador';

  @override
  String get repository => 'Repositório';

  @override
  String get bug_issues => 'Bugs/Problemas';

  @override
  String get made_with => 'Feito com ❤️ em Bangladesh🇧🇩';

  @override
  String get kingkor_roy_tirtho => 'Kingkor Roy Tirtho';

  @override
  String copyright(Object current_year) {
    return '© 2021-$current_year Kingkor Roy Tirtho';
  }

  @override
  String get license => 'Licença';

  @override
  String get credentials_will_not_be_shared_disclaimer =>
      'Não se preocupe, suas credenciais não serão coletadas nem compartilhadas com ninguém';

  @override
  String get know_how_to_login => 'Não sabe como fazer isso?';

  @override
  String get follow_step_by_step_guide => 'Siga o guia passo a passo';

  @override
  String cookie_name_cookie(Object name) {
    return 'Cookie $name';
  }

  @override
  String get fill_in_all_fields => 'Preencha todos os campos, por favor';

  @override
  String get submit => 'Enviar';

  @override
  String get exit => 'Sair';

  @override
  String get previous => 'Anterior';

  @override
  String get next => 'Próximo';

  @override
  String get done => 'Concluído';

  @override
  String get step_1 => 'Passo 1';

  @override
  String get first_go_to => 'Primeiro, vá para';

  @override
  String get something_went_wrong => 'Algo deu errado';

  @override
  String get piped_instance => 'Instância do Servidor Piped';

  @override
  String get piped_description =>
      'A instância do servidor Piped a ser usada para correspondência de faixas';

  @override
  String get piped_warning =>
      'Algumas delas podem não funcionar bem. Use por sua conta e risco';

  @override
  String get invidious_instance => 'Instância do Servidor Invidious';

  @override
  String get invidious_description =>
      'A instância do servidor Invidious a ser usada para correspondência de faixas';

  @override
  String get invidious_warning =>
      'Alguns podem não funcionar bem. Use por sua conta e risco';

  @override
  String get generate => 'Gerar';

  @override
  String track_exists(Object track) {
    return 'A faixa $track já existe';
  }

  @override
  String get replace_downloaded_tracks => 'Substituir todas as faixas baixadas';

  @override
  String get skip_download_tracks =>
      'Pular o download de todas as faixas baixadas';

  @override
  String get do_you_want_to_replace => 'Deseja substituir a faixa existente?';

  @override
  String get replace => 'Substituir';

  @override
  String get skip => 'Pular';

  @override
  String select_up_to_count_type(Object count, Object type) {
    return 'Selecione até $count $type';
  }

  @override
  String get select_genres => 'Selecionar Gêneros';

  @override
  String get add_genres => 'Adicionar Gêneros';

  @override
  String get country => 'País';

  @override
  String get number_of_tracks_generate => 'Número de faixas a gerar';

  @override
  String get acousticness => 'Acústica';

  @override
  String get danceability => 'Dançabilidade';

  @override
  String get energy => 'Energia';

  @override
  String get instrumentalness => 'Instrumentalidade';

  @override
  String get liveness => 'Vivacidade';

  @override
  String get loudness => 'Volume';

  @override
  String get speechiness => 'Discurso';

  @override
  String get valence => 'Valência';

  @override
  String get popularity => 'Popularidade';

  @override
  String get key => 'Tonalidade';

  @override
  String get duration => 'Duração (s)';

  @override
  String get tempo => 'Tempo (BPM)';

  @override
  String get mode => 'Modo';

  @override
  String get time_signature => 'Assinatura de tempo';

  @override
  String get short => 'Curto';

  @override
  String get medium => 'Médio';

  @override
  String get long => 'Longo';

  @override
  String get min => 'Min';

  @override
  String get max => 'Máx';

  @override
  String get target => 'Alvo';

  @override
  String get moderate => 'Moderado';

  @override
  String get deselect_all => 'Desmarcar Todos';

  @override
  String get select_all => 'Selecionar Todos';

  @override
  String get are_you_sure => 'Tem certeza?';

  @override
  String get generating_playlist => 'Gerando sua playlist personalizada...';

  @override
  String selected_count_tracks(Object count) {
    return '$count faixas selecionadas';
  }

  @override
  String get download_warning =>
      'Se você baixar todas as faixas em massa, estará claramente pirateando música e causando danos à sociedade criativa da música. Espero que você esteja ciente disso. Sempre tente respeitar e apoiar o trabalho árduo dos artistas';

  @override
  String get download_ip_ban_warning =>
      'Além disso, seu IP pode ser bloqueado no YouTube devido a solicitações de download excessivas. O bloqueio de IP significa que você não poderá usar o YouTube (mesmo se estiver conectado) por pelo menos 2-3 meses a partir do dispositivo IP. E o Spotube não se responsabiliza se isso acontecer';

  @override
  String get by_clicking_accept_terms =>
      'Ao clicar em \'aceitar\', você concorda com os seguintes termos:';

  @override
  String get download_agreement_1 =>
      'Eu sei que estou pirateando música. Sou mau';

  @override
  String get download_agreement_2 =>
      'Vou apoiar o artista onde puder e estou fazendo isso porque não tenho dinheiro para comprar sua arte';

  @override
  String get download_agreement_3 =>
      'Estou completamente ciente de que meu IP pode ser bloqueado no YouTube e não responsabilizo o Spotube ou seus proprietários/colaboradores por quaisquer acidentes causados pela minha ação atual';

  @override
  String get decline => 'Recusar';

  @override
  String get accept => 'Aceitar';

  @override
  String get details => 'Detalhes';

  @override
  String get youtube => 'YouTube';

  @override
  String get channel => 'Canal';

  @override
  String get likes => 'Curtidas';

  @override
  String get dislikes => 'Descurtidas';

  @override
  String get views => 'Visualizações';

  @override
  String get streamUrl => 'URL do Stream';

  @override
  String get stop => 'Parar';

  @override
  String get sort_newest => 'Ordenar por mais recente adicionado';

  @override
  String get sort_oldest => 'Ordenar por mais antigo adicionado';

  @override
  String get sleep_timer => 'Temporizador de Sono';

  @override
  String mins(Object minutes) {
    return '$minutes Minutos';
  }

  @override
  String hours(Object hours) {
    return '$hours Horas';
  }

  @override
  String hour(Object hours) {
    return '$hours Hora';
  }

  @override
  String get custom_hours => 'Horas Personalizadas';

  @override
  String get logs => 'Registros';

  @override
  String get developers => 'Desenvolvedores';

  @override
  String get not_logged_in => 'Você não está logado';

  @override
  String get search_mode => 'Modo de Busca';

  @override
  String get audio_source => 'Fonte de Áudio';

  @override
  String get ok => 'Ok';

  @override
  String get failed_to_encrypt => 'Falha ao criptografar';

  @override
  String get encryption_failed_warning =>
      'O Spotube usa criptografia para armazenar seus dados com segurança, mas falhou em fazê-lo. Portanto, ele voltará para o armazenamento não seguro.\nSe você estiver usando o Linux, certifique-se de ter algum serviço secreto (gnome-keyring, kde-wallet, keepassxc, etc.) instalado';

  @override
  String get querying_info => 'Consultando informações...';

  @override
  String get piped_api_down => 'A API do Piped está indisponível';

  @override
  String piped_down_error_instructions(Object pipedInstance) {
    return 'A instância do Piped $pipedInstance está atualmente indisponível\n\nMude a instância ou mude o \'Tipo de API\' para a API oficial do YouTube\n\nCertifique-se de reiniciar o aplicativo após a alteração';
  }

  @override
  String get you_are_offline => 'Você está offline no momento';

  @override
  String get connection_restored => 'Sua conexão com a internet foi restaurada';

  @override
  String get use_system_title_bar => 'Usar a barra de título do sistema';

  @override
  String get crunching_results => 'Processando resultados...';

  @override
  String get search_to_get_results => 'Pesquisar para obter resultados';

  @override
  String get use_amoled_mode => 'Modo AMOLED';

  @override
  String get pitch_dark_theme => 'Tema escuro';

  @override
  String get normalize_audio => 'Normalizar áudio';

  @override
  String get change_cover => 'Alterar capa';

  @override
  String get add_cover => 'Adicionar capa';

  @override
  String get restore_defaults => 'Restaurar padrões';

  @override
  String get download_music_format => 'Formato de download de música';

  @override
  String get streaming_music_format => 'Formato de streaming de música';

  @override
  String get download_music_quality => 'Qualidade de download';

  @override
  String get streaming_music_quality => 'Qualidade de streaming';

  @override
  String get login_with_lastfm => 'Iniciar sessão com o Last.fm';

  @override
  String get connect => 'Ligar';

  @override
  String get disconnect_lastfm => 'Desligar do Last.fm';

  @override
  String get disconnect => 'Desligar';

  @override
  String get username => 'Nome de utilizador';

  @override
  String get password => 'Palavra-passe';

  @override
  String get login => 'Iniciar sessão';

  @override
  String get login_with_your_lastfm => 'Inicie sessão na sua conta Last.fm';

  @override
  String get scrobble_to_lastfm => 'Scrobble para o Last.fm';

  @override
  String get go_to_album => 'Ir para o álbum';

  @override
  String get discord_rich_presence => 'Presença rica no Discord';

  @override
  String get browse_all => 'Navegar por tudo';

  @override
  String get genres => 'Gêneros';

  @override
  String get explore_genres => 'Explorar gêneros';

  @override
  String get friends => 'Amigos';

  @override
  String get no_lyrics_available =>
      'Desculpe, não foi possível encontrar a letra desta faixa';

  @override
  String get start_a_radio => 'Iniciar uma Rádio';

  @override
  String get how_to_start_radio => 'Como você deseja iniciar a rádio?';

  @override
  String get replace_queue_question =>
      'Você deseja substituir a fila atual ou acrescentar a ela?';

  @override
  String get endless_playback => 'Reprodução sem fim';

  @override
  String get delete_playlist => 'Excluir Lista de Reprodução';

  @override
  String get delete_playlist_confirmation =>
      'Tem certeza de que deseja excluir esta lista de reprodução?';

  @override
  String get local_tracks => 'Faixas Locais';

  @override
  String get local_tab => 'Local';

  @override
  String get song_link => 'Link da Música';

  @override
  String get skip_this_nonsense => 'Pular essa bobagem';

  @override
  String get freedom_of_music => '“Liberdade da Música”';

  @override
  String get freedom_of_music_palm =>
      '“Liberdade da Música na palma da sua mão”';

  @override
  String get get_started => 'Vamos começar';

  @override
  String get youtube_source_description => 'Recomendado e funciona melhor.';

  @override
  String get piped_source_description =>
      'Sentindo-se livre? Igual ao YouTube, mas muito mais grátis.';

  @override
  String get jiosaavn_source_description =>
      'Melhor para a região da Ásia do Sul.';

  @override
  String get invidious_source_description =>
      'Semelhante ao Piped, mas com maior disponibilidade.';

  @override
  String highest_quality(Object quality) {
    return 'Melhor Qualidade: $quality';
  }

  @override
  String get select_audio_source => 'Selecionar Fonte de Áudio';

  @override
  String get endless_playback_description =>
      'Adicionar automaticamente novas músicas\nao final da fila';

  @override
  String get choose_your_region => 'Escolha sua região';

  @override
  String get choose_your_region_description =>
      'Isso ajudará o Spotube a mostrar o conteúdo certo\npara sua localização.';

  @override
  String get choose_your_language => 'Escolha seu idioma';

  @override
  String get help_project_grow => 'Ajude este projeto a crescer';

  @override
  String get help_project_grow_description =>
      'Spotube é um projeto de código aberto. Você pode ajudar este projeto a crescer contribuindo para o projeto, relatando bugs ou sugerindo novos recursos.';

  @override
  String get contribute_on_github => 'Contribuir no GitHub';

  @override
  String get donate_on_open_collective => 'Doar no Open Collective';

  @override
  String get browse_anonymously => 'Navegar Anonimamente';

  @override
  String get enable_connect => 'Ativar conexão';

  @override
  String get enable_connect_description =>
      'Controle o Spotube a partir de outros dispositivos';

  @override
  String get devices => 'Dispositivos';

  @override
  String get select => 'Selecionar';

  @override
  String connect_client_alert(Object client) {
    return 'Você está sendo controlado por $client';
  }

  @override
  String get this_device => 'Este dispositivo';

  @override
  String get remote => 'Remoto';

  @override
  String get stats => 'Estatísticas';

  @override
  String and_n_more(Object count) {
    return 'e $count mais';
  }

  @override
  String get recently_played => 'Reproduzido Recentemente';

  @override
  String get browse_more => 'Ver Mais';

  @override
  String get no_title => 'Sem Título';

  @override
  String get not_playing => 'Não está a reproduzir';

  @override
  String get epic_failure => 'Fracasso épico!';

  @override
  String added_num_tracks_to_queue(Object tracks_length) {
    return 'Adicionados $tracks_length faixas à fila';
  }

  @override
  String get spotube_has_an_update => 'Spotube tem uma atualização';

  @override
  String get download_now => 'Baixar Agora';

  @override
  String nightly_version(Object nightlyBuildNum) {
    return 'Spotube Nightly $nightlyBuildNum foi lançado';
  }

  @override
  String release_version(Object version) {
    return 'Spotube v$version foi lançado';
  }

  @override
  String get read_the_latest => 'Leia o mais recente ';

  @override
  String get release_notes => 'notas de versão';

  @override
  String get pick_color_scheme => 'Escolha o esquema de cores';

  @override
  String get save => 'Salvar';

  @override
  String get choose_the_device => 'Escolha o dispositivo:';

  @override
  String get multiple_device_connected =>
      'Há vários dispositivos conectados.\nEscolha o dispositivo no qual deseja executar esta ação';

  @override
  String get nothing_found => 'Nada encontrado';

  @override
  String get the_box_is_empty => 'A caixa está vazia';

  @override
  String get top_artists => 'Principais Artistas';

  @override
  String get top_albums => 'Principais Álbuns';

  @override
  String get this_week => 'Esta semana';

  @override
  String get this_month => 'Este mês';

  @override
  String get last_6_months => 'Últimos 6 meses';

  @override
  String get this_year => 'Este ano';

  @override
  String get last_2_years => 'Últimos 2 anos';

  @override
  String get all_time => 'De todos os tempos';

  @override
  String powered_by_provider(Object providerName) {
    return 'Desenvolvido por $providerName';
  }

  @override
  String get email => 'E-mail';

  @override
  String get profile_followers => 'Seguidores';

  @override
  String get birthday => 'Aniversário';

  @override
  String get subscription => 'Assinatura';

  @override
  String get not_born => 'Não nascido';

  @override
  String get hacker => 'Hacker';

  @override
  String get profile => 'Perfil';

  @override
  String get no_name => 'Sem Nome';

  @override
  String get edit => 'Editar';

  @override
  String get user_profile => 'Perfil do Usuário';

  @override
  String count_plays(Object count) {
    return '$count reproduzidos';
  }

  @override
  String get streaming_fees_hypothetical =>
      '*Calculado com base no pagamento por stream do Spotify\nque varia de \$0.003 a \$0.005. Isso é um cálculo hipotético\npara fornecer uma visão ao usuário sobre quanto eles\nteriam pago aos artistas se estivessem ouvindo\no seu som no Spotify.';

  @override
  String get minutes_listened => 'Minutos ouvidos';

  @override
  String get streamed_songs => 'Músicas transmitidas';

  @override
  String count_streams(Object count) {
    return '$count streams';
  }

  @override
  String get owned_by_you => 'De sua propriedade';

  @override
  String copied_shareurl_to_clipboard(Object shareUrl) {
    return '$shareUrl copiado para a área de transferência';
  }

  @override
  String get hipotetical_calculation =>
      '*Isso é calculado com base no pagamento médio por stream de plataformas de streaming de música online de US\$ 0,003 a US\$ 0,005. Esta é uma estimativa hipotética para dar ao usuário uma ideia de quanto ele teria pago aos artistas se ouvisse sua música em diferentes plataformas de streaming de música.';

  @override
  String count_mins(Object minutes) {
    return '$minutes min';
  }

  @override
  String get summary_minutes => 'minutos';

  @override
  String get summary_listened_to_music => 'Música ouvida';

  @override
  String get summary_songs => 'faixas';

  @override
  String get summary_streamed_overall => 'Total de streams';

  @override
  String get summary_owed_to_artists => 'Devido aos artistas\neste mês';

  @override
  String get summary_artists => 'artista';

  @override
  String get summary_music_reached_you => 'A música chegou até você';

  @override
  String get summary_full_albums => 'álbuns completos';

  @override
  String get summary_got_your_love => 'Recebeu seu amor';

  @override
  String get summary_playlists => 'playlists';

  @override
  String get summary_were_on_repeat => 'Estavam em repetição';

  @override
  String total_money(Object money) {
    return 'Total $money';
  }

  @override
  String get webview_not_found => 'Webview não encontrado';

  @override
  String get webview_not_found_description =>
      'Nenhum runtime Webview está instalado no seu dispositivo.\nSe estiver instalado, certifique-se de que está no environment PATH\n\nApós a instalação, reinicie o aplicativo';

  @override
  String get unsupported_platform => 'Plataforma não suportada';

  @override
  String get cache_music => 'Música em cache';

  @override
  String get open => 'Abrir';

  @override
  String get cache_folder => 'Pasta de cache';

  @override
  String get export => 'Exportar';

  @override
  String get clear_cache => 'Limpar cache';

  @override
  String get clear_cache_confirmation => 'Deseja limpar o cache?';

  @override
  String get export_cache_files => 'Exportar Arquivos em Cache';

  @override
  String found_n_files(Object count) {
    return 'Encontrados $count arquivos';
  }

  @override
  String get export_cache_confirmation => 'Deseja exportar estes arquivos para';

  @override
  String exported_n_out_of_m_files(Object files, Object filesExported) {
    return 'Exportados $filesExported de $files arquivos';
  }

  @override
  String get undo => 'Desfazer';

  @override
  String get download_all => 'Baixar tudo';

  @override
  String get add_all_to_playlist => 'Adicionar tudo à playlist';

  @override
  String get add_all_to_queue => 'Adicionar tudo à fila';

  @override
  String get play_all_next => 'Reproduzir tudo a seguir';

  @override
  String get pause => 'Pausar';

  @override
  String get view_all => 'Ver tudo';

  @override
  String get no_tracks_added_yet =>
      'Parece que você ainda não adicionou nenhuma faixa';

  @override
  String get no_tracks => 'Parece que não há faixas aqui';

  @override
  String get no_tracks_listened_yet => 'Parece que você ainda não ouviu nada';

  @override
  String get not_following_artists => 'Você não está seguindo nenhum artista';

  @override
  String get no_favorite_albums_yet =>
      'Parece que você ainda não adicionou nenhum álbum aos favoritos';

  @override
  String get no_logs_found => 'Nenhum log encontrado';

  @override
  String get youtube_engine => 'Motor YouTube';

  @override
  String youtube_engine_not_installed_title(Object engine) {
    return '$engine não está instalado';
  }

  @override
  String youtube_engine_not_installed_message(Object engine) {
    return '$engine não está instalado no seu sistema.';
  }

  @override
  String youtube_engine_set_path(Object engine) {
    return 'Certifique-se de que está disponível na variável PATH ou\ndefina o caminho absoluto para o executável $engine abaixo';
  }

  @override
  String get youtube_engine_unix_issue_message =>
      'Em sistemas macOS/Linux/unix, definir o caminho no .zshrc/.bashrc/.bash_profile etc. não funcionará.\nVocê precisa definir o caminho no arquivo de configuração do shell';

  @override
  String get download => 'Baixar';

  @override
  String get file_not_found => 'Arquivo não encontrado';

  @override
  String get custom => 'Personalizado';

  @override
  String get add_custom_url => 'Adicionar URL personalizada';

  @override
  String get edit_port => 'Editar porta';

  @override
  String get port_helper_msg =>
      'O padrão é -1, que indica um número aleatório. Se você tiver um firewall configurado, é recomendável definir isso.';

  @override
  String connect_request(Object client) {
    return 'Permitir que $client se conecte?';
  }

  @override
  String get connection_request_denied =>
      'Conexão negada. O usuário negou o acesso .';

  @override
  String get an_error_occurred => 'Ocorreu um erro';

  @override
  String get copy_to_clipboard => 'Copiar para a área de transferência';

  @override
  String get view_logs => 'Ver logs';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get no_default_metadata_provider_selected =>
      'Você não tem um provedor de metadados padrão definido';

  @override
  String get manage_metadata_providers => 'Gerenciar provedores de metadados';

  @override
  String get open_link_in_browser => 'Abrir link no navegador?';

  @override
  String get do_you_want_to_open_the_following_link =>
      'Você deseja abrir o seguinte link';

  @override
  String get unsafe_url_warning =>
      'Pode ser inseguro abrir links de fontes não confiáveis. Tenha cautela!\nVocê também pode copiar o link para sua área de transferência.';

  @override
  String get copy_link => 'Copiar link';

  @override
  String get building_your_timeline =>
      'Construindo sua linha do tempo com base em suas audições...';

  @override
  String get official => 'Oficial';

  @override
  String author_name(Object author) {
    return 'Autor: $author';
  }

  @override
  String get third_party => 'Terceiros';

  @override
  String get plugin_requires_authentication => 'Plugin requer autenticação';

  @override
  String get update_available => 'Atualização disponível';

  @override
  String get supports_scrobbling => 'Suporta scrobbling';

  @override
  String get plugin_scrobbling_info =>
      'Este plugin faz o scrobbling de sua música para gerar seu histórico de audição.';

  @override
  String get default_metadata_source => 'Fonte padrão de metadados';

  @override
  String get set_default_metadata_source => 'Definir fonte padrão de metadados';

  @override
  String get default_audio_source => 'Fonte de áudio padrão';

  @override
  String get set_default_audio_source => 'Definir fonte de áudio padrão';

  @override
  String get set_default => 'Definir como padrão';

  @override
  String get support => 'Suporte';

  @override
  String get support_plugin_development => 'Apoiar o desenvolvimento do plugin';

  @override
  String can_access_name_api(Object name) {
    return '- Pode acessar a API **$name**';
  }

  @override
  String get do_you_want_to_install_this_plugin =>
      'Você deseja instalar este plugin?';

  @override
  String get third_party_plugin_warning =>
      'Este plugin é de um repositório de terceiros. Certifique-se de que você confia na fonte antes de instalá-lo.';

  @override
  String get author => 'Autor';

  @override
  String get this_plugin_can_do_following =>
      'Este plugin pode fazer o seguinte';

  @override
  String get install => 'Instalar';

  @override
  String get install_a_metadata_provider => 'Instalar um provedor de metadados';

  @override
  String get no_tracks_playing => 'Nenhuma música sendo reproduzida no momento';

  @override
  String get synced_lyrics_not_available =>
      'As letras sincronizadas não estão disponíveis para esta música. Por favor, use a aba';

  @override
  String get plain_lyrics => 'Letras simples';

  @override
  String get tab_instead => 'em vez disso.';

  @override
  String get disclaimer => 'Aviso';

  @override
  String get third_party_plugin_dmca_notice =>
      'A equipe Spotube não se responsabiliza (incluindo legalmente) por quaisquer plugins de \"terceiros\".\nUse-os por sua conta e risco. Para quaisquer bugs/problemas, por favor, relate-os ao repositório do plugin.\n\nSe algum plugin de \"terceiros\" estiver violando os Termos de Serviço/DMCA de qualquer serviço/entidade legal, por favor, peça ao autor do plugin \"terceiro\" ou à plataforma de hospedagem, por exemplo, GitHub/Codeberg, para tomar medidas. Os plugins listados acima (rotulados como \"terceiros\") são todos plugins públicos/mantidos pela comunidade. Não os estamos curando, então não podemos tomar nenhuma medida sobre eles.\n\n';

  @override
  String get input_does_not_match_format =>
      'A entrada não corresponde ao formato exigido';

  @override
  String get plugins => 'Plugins';

  @override
  String get paste_plugin_download_url =>
      'Cole a url de download ou a url do repositório GitHub/Codeberg ou o link direto para o arquivo .smplug';

  @override
  String get download_and_install_plugin_from_url =>
      'Baixar e instalar o plugin a partir da url';

  @override
  String failed_to_add_plugin_error(Object error) {
    return 'Falha ao adicionar plugin: $error';
  }

  @override
  String get upload_plugin_from_file => 'Carregar plugin a partir de arquivo';

  @override
  String get installed => 'Instalado';

  @override
  String get available_plugins => 'Plugins disponíveis';

  @override
  String get configure_plugins =>
      'Configure seus próprios plugins de provedores de metadados e fontes de áudio';

  @override
  String get audio_scrobblers => 'Scrobblers de áudio';

  @override
  String get scrobbling => 'Scrobbling';

  @override
  String get source => 'Fonte: ';

  @override
  String get uncompressed => 'Não comprimido';

  @override
  String get dab_music_source_description =>
      'Para audiófilos. Fornece streams de áudio de alta qualidade/sem perdas. Correspondência precisa de faixas baseada em ISRC.';
}
