import { ComponentFixture, TestBed } from '@angular/core/testing';

import { MobiliShared } from './mobili-shared';

describe('MobiliShared', () => {
  let component: MobiliShared;
  let fixture: ComponentFixture<MobiliShared>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MobiliShared]
    })
    .compileComponents();

    fixture = TestBed.createComponent(MobiliShared);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
