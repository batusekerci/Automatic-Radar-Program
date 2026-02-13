# Automatic-Radar-Program
An image processing project that automatically detects vehicle speeds from surveillance camera footages

## About the Project

This project analyzes traffic video recorded from a fixed surveillance camera, detects vehicles on the road frame by frame, tracks them, and calculates their speeds in km/h. The program consists of macro files that run on the **Fiji (ImageJ)** platform.

Vehicles in the video are analyzed with two separate macros based on their color characteristics:

- **White vehicles** — segmentation is performed using brightness thresholding.
- **Dark-colored vehicles** — segmentation is achieved under more challenging conditions by combining edge detection and dark pixel thresholding.

Both macros track vehicles frame by frame, filter out static objects, correct perspective-based distance differences using calibration coefficients, and produce average speed information for each vehicle.

## Methods Used

- Color and brightness-based thresholding
- Edge detection
- Morphological operations (dilate, erode, despeckle, fill holes)
- Particle analysis
- Frame-by-frame object tracking
- Calibration function for perspective correction
- Static object filtering (blacklist mechanism)
- Fragmented track merging

## How to Run

1. Download and install [Fiji (ImageJ)](https://fiji.sc/).
2. Open the video you want to analyze in Fiji.
3. Run the relevant `.ijm` macro file via **Plugins > Macros > Run...**
4. Results are displayed in the **Vehicle_Tracks** table and the Log window.

## Files

| File | Description |
|------|-------------|
| `Automatic Radar Program For White Cars.ijm` | Detection and speed analysis of white/light-colored vehicles |
| `Automatic Radar Program For Dark Colored Cars.ijm` | Detection and speed analysis of dark-colored vehicles |

---

# Otomatik Radar Programı

Güvenlik kamerası görüntüleri üzerinden araçların hızını otomatik olarak tespit eden bir görüntü işleme projesidir.

## Proje Hakkında

Bu proje, sabit bir güvenlik kamerasından kaydedilen trafik videosunu analiz ederek yol üzerindeki araçları algılar, kare kare takip eder ve hızlarını km/sa cinsinden hesaplar. Program, **Fiji (ImageJ)** platformunda çalışan macro dosyalarından oluşmaktadır.

Videodaki araçlar renk özelliklerine göre iki ayrı macro ile analiz edilmektedir:

- **Beyaz araçlar** — parlaklık eşikleme yöntemiyle segmentasyon yapılır.
- **Koyu renkli araçlar** — kenar algılama ve karanlık piksel eşiklemesi birlikte kullanılarak daha zorlu koşullarda segmentasyon sağlanır.

Her iki macro da araçları kare kare takip eder, statik nesneleri filtreler, perspektif kaynaklı mesafe farklarını kalibrasyon katsayılarıyla düzeltir ve her araç için ortalama hız bilgisi üretir.

## Kullanılan Yöntemler

- Renk ve parlaklık tabanlı eşikleme (thresholding)
- Kenar algılama (edge detection)
- Morfolojik işlemler (dilate, erode, despeckle, fill holes)
- Parçacık analizi (particle analysis)
- Kare bazlı nesne takibi (frame-by-frame tracking)
- Perspektif düzeltmesi için kalibrasyon fonksiyonu
- Statik nesne filtreleme (blacklist mekanizması)
- Parçalanmış takiplerin birleştirilmesi (track merging)

## Nasıl Çalıştırılır

1. [Fiji (ImageJ)](https://fiji.sc/) programını indirin ve kurun.
2. Analiz etmek istediğiniz videoyu Fiji'de açın.
3. İlgili `.ijm` macro dosyasını **Plugins > Macros > Run...** yoluyla çalıştırın.
4. Sonuçlar **Vehicle_Tracks** tablosunda ve Log penceresinde görüntülenir.

## Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `Automatic Radar Program For White Cars.ijm` | Beyaz/açık renkli araçların tespiti ve hız analizi |
| `Automatic Radar Program For Dark Colored Cars.ijm` | Koyu renkli araçların tespiti ve hız analizi |
