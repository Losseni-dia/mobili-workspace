import { Directive, EventEmitter, HostListener, Output } from '@angular/core';

@Directive({
  selector: '[appImagePan]',
  standalone: true,
})
export class ImagePanDirective {
  @Output() positionChange = new EventEmitter<{ x: number; y: number }>();

  private isDragging = false;
  private startX = 0;
  private startY = 0;
  private currentX = 50;
  private currentY = 50;

  @HostListener('mousedown', ['$event'])
  @HostListener('touchstart', ['$event'])
  startDrag(event: MouseEvent | TouchEvent) {
    this.isDragging = true;
    const e = event instanceof MouseEvent ? event : event.touches[0];
    this.startX = e.clientX;
    this.startY = e.clientY;
    document.body.style.cursor = 'grabbing';
  }

  @HostListener('window:mousemove', ['$event'])
  @HostListener('window:touchmove', ['$event'])
  onDrag(event: MouseEvent | TouchEvent) {
    if (!this.isDragging) return;
    const e = event instanceof MouseEvent ? event : event.touches[0];

    const deltaX = (e.clientX - this.startX) * 0.2;
    const deltaY = (e.clientY - this.startY) * 0.2;

    this.currentX = Math.min(100, Math.max(0, this.currentX - deltaX));
    this.currentY = Math.min(100, Math.max(0, this.currentY - deltaY));

    this.positionChange.emit({ x: this.currentX, y: this.currentY });
    this.startX = e.clientX;
    this.startY = e.clientY;
  }

  @HostListener('window:mouseup')
  @HostListener('window:touchend')
  stopDrag() {
    this.isDragging = false;
    document.body.style.cursor = 'default';
  }
}
