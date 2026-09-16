const { notificationPriority } = require('./admin_notifications');

describe('admin notification priority', () => {
  test('CRITICAL is critical', () => {
    expect(notificationPriority('CRITICAL')).toBe('critical');
  });

  test('ADMIN_ALERT is high', () => {
    expect(notificationPriority('ADMIN_ALERT')).toBe('high');
  });

  test('other levels are normal', () => {
    expect(notificationPriority('WARNING')).toBe('normal');
    expect(notificationPriority('NORMAL')).toBe('normal');
  });
});
