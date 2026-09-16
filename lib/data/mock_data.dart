import 'models/cinema_model.dart';
import 'models/movie_model.dart';
import 'models/showtime_model.dart';
import 'models/ticket_model.dart';

class MockData {
  static final List<Cinema> cinemas = [
    const Cinema(
      id: 'c1',
      name: 'Cinemark Mallplaza Trujillo',
      city: 'Trujillo',
      address: 'Av. América Oeste 750, Mallplaza Trujillo',
      isRecommended: true,
      distanceKm: 1.2,
    ),
    const Cinema(
      id: 'c2',
      name: 'Cinemark San Miguel',
      city: 'Lima',
      address: 'Av. La Marina 2000, Plaza San Miguel',
      distanceKm: 550.0,
    ),
    const Cinema(
      id: 'c3',
      name: 'Cinemark Jockey Plaza',
      city: 'Lima',
      address: 'Av. Javier Prado Este 4200, Surco',
      distanceKm: 560.0,
    ),
    const Cinema(
      id: 'c4',
      name: 'Cinemark Angamos',
      city: 'Lima',
      address: 'Av. Angamos Este 1803, Surquillo',
      distanceKm: 558.0,
    ),
  ];

  static List<Showtime> generateSpiderManShowtimes() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day1 = today.add(const Duration(days: 1));
    final day2 = today.add(const Duration(days: 2));
    final day3 = today.add(const Duration(days: 3));

    return [
      // Hoy - Mallplaza Trujillo
      Showtime(
        id: 'st-sm-01',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: today,
        timeFormatted: '13:10',
        roomName: 'Sala 2',
        format: '2D',
        language: 'Doblada',
        totalSeats: 120,
        availableSeats: 45,
      ),
      Showtime(
        id: 'st-sm-02',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: today,
        timeFormatted: '16:20',
        roomName: 'Sala 2',
        format: '2D',
        language: 'Doblada',
        totalSeats: 120,
        availableSeats: 62,
      ),
      Showtime(
        id: 'st-sm-03',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: today,
        timeFormatted: '19:20',
        roomName: 'Sala XD 1',
        format: 'XD',
        language: 'Doblada',
        totalSeats: 160,
        availableSeats: 14,
      ),
      Showtime(
        id: 'st-sm-04',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: today,
        timeFormatted: '22:15',
        roomName: 'Sala 3',
        format: '2D',
        language: 'Subtitulada',
        totalSeats: 120,
        availableSeats: 0, // Agotado para prevenir errores de usuario
      ),
      // Mañana
      Showtime(
        id: 'st-sm-05',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: day1,
        timeFormatted: '14:00',
        roomName: 'Sala 2',
        format: '2D',
        language: 'Doblada',
        totalSeats: 120,
        availableSeats: 80,
      ),
      Showtime(
        id: 'st-sm-06',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: day1,
        timeFormatted: '17:30',
        roomName: 'Sala XD 1',
        format: 'XD',
        language: 'Doblada',
        totalSeats: 160,
        availableSeats: 48,
      ),
      Showtime(
        id: 'st-sm-07',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: day1,
        timeFormatted: '20:45',
        roomName: 'Sala D-BOX 4',
        format: 'D-BOX',
        language: 'Subtitulada',
        totalSeats: 90,
        availableSeats: 22,
      ),
      // Pasado mañana
      Showtime(
        id: 'st-sm-08',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: day2,
        timeFormatted: '15:15',
        roomName: 'Sala 2',
        format: '2D',
        language: 'Doblada',
        totalSeats: 120,
        availableSeats: 95,
      ),
      Showtime(
        id: 'st-sm-09',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: day2,
        timeFormatted: '18:40',
        roomName: 'Sala XD 1',
        format: 'XD',
        language: 'Doblada',
        totalSeats: 160,
        availableSeats: 60,
      ),
      // Día 3
      Showtime(
        id: 'st-sm-10',
        movieId: 'm-spiderman',
        cinemaId: 'c1',
        date: day3,
        timeFormatted: '16:00',
        roomName: 'Sala 2',
        format: '2D',
        language: 'Doblada',
        totalSeats: 120,
        availableSeats: 110,
      ),
    ];
  }

  static List<Showtime> generateAvengersShowtimes() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      Showtime(
        id: 'st-av-01',
        movieId: 'm-avengers',
        cinemaId: 'c1',
        date: today,
        timeFormatted: '15:00',
        roomName: 'Sala XD 1',
        format: 'XD',
        language: 'Doblada',
        totalSeats: 160,
        availableSeats: 35,
      ),
      Showtime(
        id: 'st-av-02',
        movieId: 'm-avengers',
        cinemaId: 'c1',
        date: today,
        timeFormatted: '19:00',
        roomName: 'Sala D-BOX',
        format: 'D-BOX',
        language: 'Subtitulada',
        totalSeats: 80,
        availableSeats: 8,
      ),
    ];
  }

  static List<Movie> getMovies() {
    final spiderManShowtimes = generateSpiderManShowtimes();
    final avengersShowtimes = generateAvengersShowtimes();

    return [
      Movie(
        id: 'm-spiderman',
        title: 'SPIDER MAN UN NUEVO DIA',
        posterUrl:
            'https://images.unsplash.com/photo-1635805737707-575885ab0820?auto=format&fit=crop&w=600&q=80',
        backdropUrl:
            'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=1200&q=80',
        rating: 'APT',
        ratingDescription: 'Apto para todo Público',
        duration: '2H 30M',
        genre: 'Acción / Aventura',
        synopsis:
            'Peter Parker debe enfrentarse a nuevas amenazas que ponen en riesgo la seguridad de su ciudad, mientras intenta reconstruir su vida y equilibrar sus responsabilidades como héroe.',
        director: 'Jon Watts',
        cast: 'Tom Holland, Zendaya, Benedict Cumberbatch',
        formats: const ['2D', 'XD', 'D-BOX'],
        isNowPlaying: true,
        releaseBadge: 'ESTRENO',
        trailerUrl: 'https://www.youtube.com/watch?v=JfVOs4VSpmA',
        showtimes: spiderManShowtimes,
      ),
      Movie(
        id: 'm-hechizo',
        title: 'HECHIZO DE AMOR LA MAGIA CONTINUA',
        posterUrl:
            'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=600&q=80',
        backdropUrl:
            'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=1200&q=80',
        rating: 'APT',
        ratingDescription: 'Apto para todo Público',
        duration: '1H 45M',
        genre: 'Romance / Comedia',
        synopsis:
            'Dos almas gemelas descubren que la magia del amor supera cualquier distancia y dimensión.',
        director: 'Griffin Dunne',
        cast: 'Sandra Bullock, Nicole Kidman',
        formats: const ['2D'],
        isFeatured: true,
        isNowPlaying: true,
        releaseBadge: 'ESTRENO',
        showtimes: [
          Showtime(
            id: 'st-ha-01',
            movieId: 'm-hechizo',
            cinemaId: 'c1',
            date: DateTime.now(),
            timeFormatted: '18:10',
            roomName: 'Sala 4',
            format: '2D',
            language: 'Doblada',
            totalSeats: 100,
            availableSeats: 32,
          ),
        ],
      ),
      Movie(
        id: 'm-avengers',
        title: 'AVENGERS ENDGAME [RE-ESTRENO]',
        posterUrl:
            'https://images.unsplash.com/photo-1563089145-599997674d42?auto=format&fit=crop&w=600&q=80',
        backdropUrl:
            'https://images.unsplash.com/photo-1618336753974-aae8e04506aa?auto=format&fit=crop&w=1200&q=80',
        rating: 'APT',
        ratingDescription: 'Apto para todo Público',
        duration: '3H 05M',
        genre: 'Acción / Fantasía',
        synopsis:
            'Los Vengadores restantes deben reunirse una vez más para deshacer las acciones de Thanos y restaurar el orden en el universo.',
        director: 'Anthony Russo, Joe Russo',
        cast: 'Robert Downey Jr., Chris Evans, Scarlett Johansson',
        formats: const ['3D', 'D-BOX', 'XD'],
        isPresale: true,
        releaseBadge: 'Re-Estreno',
        showtimes: avengersShowtimes,
      ),
      Movie(
        id: 'm-madoka',
        title: 'PUELLA MAGI MADOKA MAGICA',
        posterUrl:
            'https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=600&q=80',
        backdropUrl:
            'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=1200&q=80',
        rating: 'M14',
        ratingDescription: 'Mayores de 14 años',
        duration: '2H 00M',
        genre: 'Anime / Fantasía',
        synopsis:
            'Una historia mágica donde el destino, los deseos y las decisiones transforman el mundo.',
        director: 'Akiyuki Shinbo',
        cast: 'Aoi Yuki, Chiwa Saito',
        formats: const ['2D'],
        isPresale: true,
        releaseBadge: 'Cinemark No SeKai',
        showtimes: [
          Showtime(
            id: 'st-mm-01',
            movieId: 'm-madoka',
            cinemaId: 'c1',
            date: DateTime.now(),
            timeFormatted: '20:00',
            roomName: 'Sala 1',
            format: '2D',
            language: 'Subtitulada',
            totalSeats: 110,
            availableSeats: 55,
          ),
        ],
      ),
      Movie(
        id: 'm-onepiece',
        title: 'ONE PIECE: LA PELICULA [2026]',
        posterUrl:
            'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=600&q=80',
        backdropUrl:
            'https://images.unsplash.com/photo-1563089145-599997674d42?auto=format&fit=crop&w=1200&q=80',
        rating: 'APT',
        ratingDescription: 'Apto para todo Público',
        duration: '1H 57M',
        genre: 'Anime / Aventura',
        synopsis:
            'Luffy y los Piratas de Sombrero de Paja zarpan hacia una isla misteriosa repleta de desafíos y tesoros legendarios.',
        director: 'Goro Taniguchi',
        cast: 'Mayumi Tanaka, Kazuya Nakai',
        formats: const ['2D', 'XD'],
        isPresale: true,
        releaseBadge: 'Cinemark No SeKai',
        showtimes: [
          Showtime(
            id: 'st-op-01',
            movieId: 'm-onepiece',
            cinemaId: 'c1',
            date: DateTime.now(),
            timeFormatted: '17:00',
            roomName: 'Sala XD 1',
            format: 'XD',
            language: 'Doblada',
            totalSeats: 160,
            availableSeats: 70,
          ),
        ],
      ),
      Movie(
        id: 'm-coyote',
        title: 'COYOTE VS ACME',
        posterUrl:
            'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=600&q=80',
        backdropUrl:
            'https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=1200&q=80',
        rating: 'APT',
        ratingDescription: 'Apto para todo Público',
        duration: '1H 44M',
        genre: 'Comedia / Animación',
        synopsis:
            'Wile E. Coyote decide llevar a juicio a la Corporación ACME tras años de artefactos defectuosos.',
        director: 'Dave Green',
        cast: 'Will Forte, John Cena, Lana Condor',
        formats: const ['2D', 'DBOX', 'XD'],
        isNowPlaying: true,
        showtimes: [
          Showtime(
            id: 'st-ca-01',
            movieId: 'm-coyote',
            cinemaId: 'c1',
            date: DateTime.now(),
            timeFormatted: '15:45',
            roomName: 'Sala 5',
            format: '2D',
            language: 'Doblada',
            totalSeats: 90,
            availableSeats: 40,
          ),
        ],
      ),
      // Película que NO está en Trujillo (permite validar la heurística de no inducir a error)
      Movie(
        id: 'm-ceviche',
        title: 'CEVICHE',
        posterUrl:
            'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=600&q=80',
        backdropUrl:
            'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=1200&q=80',
        rating: 'M14',
        ratingDescription: 'Mayores de 14 años',
        duration: '1H 18M',
        genre: 'Documental',
        synopsis:
            'Un viaje culinario y patrimonial por los secretos del plato bandera peruano.',
        director: 'Orlando Arriagada',
        cast: 'Chefs Peruanos',
        formats: const ['2D'],
        isNowPlaying: false,
        isComingSoon: false,
        releaseBadge: '10 DE SETIEMBRE',
        showtimes: [
          // Solo disponible en Lima San Miguel, NO en Trujillo
          Showtime(
            id: 'st-cev-01',
            movieId: 'm-ceviche',
            cinemaId: 'c2',
            date: DateTime.now(),
            timeFormatted: '19:00',
            roomName: 'Sala 1',
            format: '2D',
            language: 'Español',
            totalSeats: 80,
            availableSeats: 25,
          ),
        ],
      ),
    ];
  }

  static List<TicketType> getTicketTypes() {
    return const [
      // Categoría destacada / promocional
      TicketType(
        id: 't-fiesta',
        name: 'FIESTA DEL CINE',
        description: 'Tarifa especial promocional para todas las edades.',
        price: 7.50,
        category: 'Tarifas Destacadas',
        isRecommended: true,
      ),
      TicketType(
        id: 't-club',
        name: 'ENTRADA + 50 PUNTOS CLUB',
        description: 'Beneficio exclusivo socios Club Cinemark.',
        price: 10.90,
        category: 'Beneficios Club',
        isMemberOnly: true,
        pointsBonus: 50,
      ),
      TicketType(
        id: 't-general',
        name: 'GENERAL ADULTO',
        description: 'Tarifa regular para personas mayores de 13 años.',
        price: 18.00,
        category: 'General',
      ),
      TicketType(
        id: 't-ninos',
        name: 'NIÑOS / ADULTO MAYOR',
        description: 'Niños de 2 a 12 años y mayores de 60 años con DNI.',
        price: 14.00,
        category: 'General',
      ),
      TicketType(
        id: 't-conadis',
        name: 'PERSONA CON DISCAPACIDAD',
        description: 'Válido presentando carnet CONADIS.',
        price: 7.50,
        category: 'Preferencial',
      ),
      TicketType(
        id: 't-wheelchair',
        name: 'SILLA DE RUEDAS',
        description: 'Espacio acondicionado en sala.',
        price: 7.50,
        category: 'Preferencial',
      ),
    ];
  }

  static BatchCoupon? resolveBatchCoupon(String code) {
    final cleanCode = code.trim().toUpperCase();

    if (cleanCode == 'PACK3X' || cleanCode == 'CINEMARK-3X') {
      return BatchCoupon(
        code: cleanCode,
        title: 'Pack Promocional 3x Entradas',
        description: 'Cupón corporativo válido por 3 entradas generales 2D.',
        totalTickets: 3,
        generatedTickets: [
          RedeemedCouponTicket(
            id: 'coupon-tk-1-${DateTime.now().millisecondsSinceEpoch}',
            parentBatchCode: cleanCode,
            title: 'Entrada Canje 1/3 (2D)',
          ),
          RedeemedCouponTicket(
            id: 'coupon-tk-2-${DateTime.now().millisecondsSinceEpoch}',
            parentBatchCode: cleanCode,
            title: 'Entrada Canje 2/3 (2D)',
          ),
          RedeemedCouponTicket(
            id: 'coupon-tk-3-${DateTime.now().millisecondsSinceEpoch}',
            parentBatchCode: cleanCode,
            title: 'Entrada Canje 3/3 (2D)',
          ),
        ],
      );
    }

    if (cleanCode == 'CORP2X' || cleanCode == 'DUO') {
      return BatchCoupon(
        code: cleanCode,
        title: 'Cupón Corporativo Dúo (2x)',
        description: 'Canje de 2 entradas de cortesía.',
        totalTickets: 2,
        generatedTickets: [
          RedeemedCouponTicket(
            id: 'coupon-tk-1-${DateTime.now().millisecondsSinceEpoch}',
            parentBatchCode: cleanCode,
            title: 'Entrada Canje Dúo 1/2 (2D)',
          ),
          RedeemedCouponTicket(
            id: 'coupon-tk-2-${DateTime.now().millisecondsSinceEpoch}',
            parentBatchCode: cleanCode,
            title: 'Entrada Canje Dúo 2/2 (2D)',
          ),
        ],
      );
    }

    if (cleanCode == 'TICKET1X' || cleanCode == 'CORTESIA') {
      return BatchCoupon(
        code: cleanCode,
        title: 'Entrada de Cortesía Individual',
        description: 'Canje individual 2D.',
        totalTickets: 1,
        generatedTickets: [
          RedeemedCouponTicket(
            id: 'coupon-tk-1-${DateTime.now().millisecondsSinceEpoch}',
            parentBatchCode: cleanCode,
            title: 'Entrada de Cortesía (2D)',
          ),
        ],
      );
    }

    return null;
  }
}
