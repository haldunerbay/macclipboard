# Clip History

[English](README.md) | **Türkçe**

[![CI](https://github.com/haldunerbay/macclipboard/actions/workflows/ci.yml/badge.svg)](https://github.com/haldunerbay/macclipboard/actions/workflows/ci.yml)

macOS için küçük, açık kaynaklı bir pano geçmişi. Menü çubuğunda çalışır; kopyaladığınız her
şeyi ve aldığınız her ekran görüntüsünü saklar, kategorilere ayırır ve **⇧⌘V** ile geri getirir:
aramak için yazın, ↑ ↓ ile seçin, yapıştırmak için ↩'e basın.

Yerel Swift (SwiftUI + AppKit), bağımlılık yok, hiçbir şey Mac'inizin dışına çıkmaz.

## Özellikler

- **Kaydeder:** metinleri, bağlantıları, görselleri, Finder'da kopyalanan dosyaları ve ekran
  görüntülerini: dosyaya kaydedilen her ekran görüntüsünü (macOS nereye kaydederse kaydetsin,
  Spotlight ile bulunur) ve panoya alınan ekran görüntülerini (⌃⇧⌘3/4).
- **⇧⌘V ile açılan pencere** (ya da seçtiğiniz bir kısayol): en yeniler üstte, kategori
  sekmeleriyle: Tümü, Metin, Bağlantılar, Görseller, Dosyalar, Ekran görüntüleri.
- **Arama:** büyük/küçük harfi ve aksanları dikkate almaz (Türkçe dahil: "istanbul" yazınca
  "İSTANBUL" bulunur). Varsayılan esnek mod yazım hatalarını da bulur ("raed" ya da "red" yazınca
  "read" bulunur) ve sonuçları sıralar: tam kelime, kelime başı, kelime içi, sonra benzer
  kelimeler. Eşleşmeler önizlemede vurgulanır ve bulunanlar listelenir.
- **Yapıştırma:** ↩ öğeyi önceki uygulamaya yapıştırır, ⌘↩ yalnızca kopyalar.
- **Önizleme:** metin, bağlantı, görsel ve ekran görüntüleri; her öğenin nereden ve ne zaman
  kopyalandığıyla birlikte.
- **Sınırlar:** en yeni N öğeyi, N MB'a kadar en yeni öğeleri ya da hepsini saklayın; isterseniz
  N günden eski öğeleri silin.
- **Gizlilik:** parola yöneticilerinin gizli ya da geçici olarak işaretlediği öğeler hiç
  kaydedilmez.
- **Türkçe ve İngilizce** arayüz, ayarlardan değiştirilebilir.
- Oturum açılınca başlar; kaydı menü çubuğundan duraklatabilirsiniz.

## Gereksinimler

- macOS 14 Sonoma ya da üstü
- Derlemek için Xcode 16 ya da üstü (Swift 6 araç zinciri)

## Kurulum

1. [Son sürümden](https://github.com/haldunerbay/macclipboard/releases/latest)
   **ClipHistory-….dmg** dosyasını indirip açın.
2. **Clip History**'yi **Uygulamalar** klasörüne sürükleyin.
3. Clip History'yi Uygulamalar'dan açın. Uygulama henüz Apple tarafından onaylanmadığı (notarize
   edilmediği) için macOS ilk açılışta uygulamayı doğrulayamadığını söyler. **Bitti**'ye tıklayın,
   **Sistem Ayarları › Gizlilik ve Güvenlik**'i açın, aşağı kaydırıp **Yine de Aç**'a, ardından
   **Aç**'a tıklayın. Bu yalnızca bir kez gerekir.
4. İstendiğinde **Erişilebilirlik** izni verin; böylece ↩ sizin yerinize yapıştırabilir.

Uygulama Apple silicon ve Intel Mac'lerde çalışır. Güncellemek için uygulamadan çıkın ve yeni
sürümle değiştirin; macOS ardından Erişilebilirlik iznini yeniden ister (Sistem Ayarları ›
Gizlilik ve Güvenlik › Erişilebilirlik'teki eski Clip History kaydını kaldırıp yeniden açın).

### Kaynaktan derleme

```bash
git clone https://github.com/haldunerbay/macclipboard.git
cd macclipboard
make install
```

`make install` sürüm derlemesini yapar, imzalar, **Clip History.app**'i `/Applications` klasörüne
kopyalar ve başlatır. Apple Development sertifikanız varsa onunla, yoksa ad hoc imzalar; ad hoc
imzayla macOS her yeniden derlemeden sonra Erişilebilirlik iznini yeniden ister. Diğer hedefler:
`make app` (yalnızca derler, `build/` içine), `make dmg` (Apple silicon ve Intel için indirme
dosyası), `make run`, `make test`.

## Kullanım

| Tuş          | İşlev                                                                   |
| ------------ | ----------------------------------------------------------------------- |
| ⇧⌘V          | geçmişi açar ya da kapatır                                              |
| yazın        | tüm öğelerde arar                                                       |
| ↑ ↓          | listede gezinir (⌘↑ ⌘↓ ilk ve son, Page Up ve Page Down 8'er)           |
| ↩            | seçili öğeyi önceki uygulamaya yapıştırır                               |
| ⌘↩           | yalnızca panoya kopyalar                                                |
| ⇥ ⇧⇥, ⌘1…⌘6  | kategori değiştirir                                                     |
| ⌘⌫           | seçili öğeyi geçmişten siler                                            |
| esc          | önce aramayı temizler, sonra kapatır                                    |
| ⌘, ya da ⚙   | ayarlar                                                                 |

Çift tıklamak da yapıştırır. `open cliphistory://show` pencereyi betiklerden (Kestirmeler,
Raycast), `open cliphistory://settings` ayarları açar.

Arama yaparken Tümü sekmesi, liste hızlı kalsın diye ekran görüntülerini göstermez; Ekran
görüntüleri sekmesi onları dosya adına göre arar.

## Ayarlar

- **Genel:** dil (English, Türkçe), oturum açınca başlatma.
- **Arama:** tam metin ya da esnek (yazım hatalarını tolere eder).
- **Geçmiş:** en yeni N öğeyi (varsayılan 500), N MB'a kadar en yeni öğeleri (metinler, dosya
  yolları ve kopyalanan görseller; ekran görüntüsü dosyaları sayılmaz) ya da hepsini saklar.
  Sınır aşıldığında yeni bir öğe gelince en eski öğeler silinir. İsterseniz öğeler son
  kopyalanmalarından ya da yapıştırılmalarından N gün sonra silinir; bu, açılışta, geçmiş
  açıldığında, her kopyalamada ve 10 dakikada bir kontrol edilir.
- **Kısayol:** tıklayıp yeni tuşlara basın (⌘, ⌥ ya da ⌃ gerekir; esc iptal eder, Sıfırla ⇧⌘V'ye
  döndürür).

## İzinler

- **Erişilebilirlik**, ilk açılışta istenir: ⌘V'ye sizin yerinize basmak için gerekir. Bu izin
  olmadan ↩ öğeyi kopyalar, ⌘V ile siz yapıştırırsınız.
- **Masaüstü, Belgeler, İndirilenler:** oradaki bir ekran görüntüsü ilk kez gösterildiğinde
  istenir.
- macOS, Clip History'nin diğer uygulamaların kopyaladıklarını okuyup okuyamayacağını bir kez
  sorabilir: **İzin Ver**'i seçin.

⇧⌘V bazı uygulamalarda "Yapıştır ve Stili Eşle" kısayoludur; Clip History çalışırken bu kısayol
geçmişi açar. Gerekirse ayarlardan başka bir kısayol seçin.

## Gizlilik

Geçmiş Mac'inizde, `~/Library/Application Support/ClipHistory/` klasöründe kalır (bir JSON dosyası
ve kopyalanan görseller). Uygulama hiçbir ağ isteği yapmaz. Ekran görüntüsü dosyaları macOS'un
kaydettiği yerde kalır; bir ekran görüntüsünü silmek onu geçmişten de kaldırır. Menü çubuğundaki
**Geçmişi Temizle…** geçmişi boşaltır.

## Geliştirme

```text
Sources/ClipCore/      model, arama (esnek eşleştirme, sıralama, vurgular), geçmiş deposu
Sources/ClipHistory/   uygulama: pano ve ekran görüntüsü izleyicileri, pencere, ayarlar, kısayol, yapıştırma
Tests/                 ikisi için birim testleri (Swift Testing)
Support/Info.plist     uygulama paketinin Info.plist dosyası
Makefile               derleme, paketleme, imzalama, kurulum
```

```bash
make test        # ya da: swift test
swift build      # çalıştırılabilir dosyanın hata ayıklama derlemesi
```

Sorun bildirimleri ve pull request'ler memnuniyetle karşılanır. Lütfen her değişiklikle bir test
ekleyin ve `make test`'i yeşil tutun; GitHub Actions her push'u ve pull request'i derleyip test
eder.

Sürüm yayınlamak için bir sürüm etiketi gönderin: `git tag v1.2.0 && git push origin v1.2.0`.
Release iş akışı testleri çalıştırır, `ClipHistory-1.2.0.dmg` dosyasını derler ve Releases
sayfasında yayınlar.

## Lisans

[MIT](LICENSE)
