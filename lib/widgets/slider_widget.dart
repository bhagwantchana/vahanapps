// import 'package:fleet_monitor/models/banner_model.dart';
// import 'package:carousel_slider/carousel_slider.dart';
// import 'package:dots_indicator/dots_indicator.dart';
// import 'package:flutter/material.dart';

// class SliderWidget extends StatefulWidget {
//   final BannerModel? bannerModel;
//   const SliderWidget({this.bannerModel, super.key});

//   @override
//   State<SliderWidget> createState() => _SliderWidgetState();
// }

// class _SliderWidgetState extends State<SliderWidget> {
//   final CarouselSliderController _controller = CarouselSliderController();
//   double _current = 0;
//   @override
//   Widget build(BuildContext context) {
//     Size? screenSize = MediaQuery.sizeOf(context);
//     return Column(
//       children: [
//         CarouselSlider(
//           items: widget.bannerModel!.data!
//               .map(
//                 (imagedata) => InkWell(
//                   onTap: () {
//                     // lunchwebview(imagedata.webLink.toString());
//                   },
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(8.0),
//                     child: Stack(
//                       fit: StackFit.loose,
//                       children: [
//                         Image.network(imagedata.imageUrl!, fit: BoxFit.cover),
//                         Container(
//                           decoration: BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: [
//                                 Colors.black.withValues(alpha: 0.3),
//                                 Colors.transparent,
//                               ],
//                               begin: Alignment.bottomCenter,
//                               end: Alignment.topCenter,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               )
//               .toList(),
//           carouselController: _controller,
//           options: CarouselOptions(
//             height: screenSize.height / 4.5,
//             autoPlay: true,
//             enlargeCenterPage: true,
//             aspectRatio: 16 / 9,
//             viewportFraction: 0.9,
//             initialPage: 0,
//             enableInfiniteScroll: true,
//             autoPlayInterval: Duration(seconds: 3),
//             autoPlayAnimationDuration: Duration(milliseconds: 800),
//             autoPlayCurve: Curves.fastOutSlowIn,
//             enlargeFactor: 0.3,
//             scrollDirection: Axis.horizontal,
//             onPageChanged: (index, reason) {
//               setState(() {
//                 _current = index.toDouble();
//               });
//             },
//           ),
//         ),
//         Padding(
//           padding: const EdgeInsets.only(left: 9.5, right: 9.5),
//           child: DotsIndicator(
//             dotsCount: widget.bannerModel!.data!.length,
//             position: _current,
//             axis: Axis.horizontal,
//             reversed: false,
//             decorator: DotsDecorator(
//               color: Colors.black87,
//               activeColor: Colors.redAccent,
//               size: const Size.fromRadius(2.0),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
