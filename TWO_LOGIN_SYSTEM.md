# Two-Login System Implementation Guide

## Overview

The student management system now features two separate, specialized login portals:

1. **Headmaster Login** - For school administrators
2. **Teacher Login** - For teaching staff

Users first select their role on a dedicated role selection screen before accessing the appropriate login portal.

---

## User Flow

### New User Workflow

```
App Launch
    ↓
Splash Screen (1.6s)
    ↓
Role Selection Screen
    ├─ Headmaster? → Headmaster Login
    ├─ Teacher? → Teacher Login
    └─ No Account? → Signup (Teacher only)
    ↓
Enter Credentials
    ↓
Dashboard
```

### Account Creation Workflow

#### Step 1: Headmaster Creates Teacher Account

- Headmaster logs in → Dashboard → Teacher Management
- Click "Add Teacher" button
- Fill in:
  - Teacher Name
  - Email Address
  - Subjects (select multiple)
  - Assigned Classes (select multiple)
- Click "Create" to save the account

#### Step 2: Teacher Receives Account Details

- Teacher receives email with their account credentials
- Email: Provided during account creation
- Password: Initial password set by headmaster (or generated)
- Note: Teachers may need to change password on first login

#### Step 3: Teacher Logs In

- Teacher launches app → Splash → Role Selection
- Clicks "Teacher" button
- Enters email and password from headmaster
- Successfully logs in to Dashboard

---

## Screen Structure

### 1. Role Selection Screen (`role_selection_screen.dart`)

**Path:** `/role-selection`

A friendly welcome screen showing two options:

**Headmaster Card:**

- Icon: Security badge
- Color: Blue (#155EEF)
- Description: School administrator with full system access
- Action: Routes to `/headmaster-login`

**Teacher Card:**

- Icon: Person
- Color: Green (#10B981)
- Description: Upload results and manage student records
- Action: Routes to `/teacher-login`

**Additional Actions:**

- Back button from any login screen returns here
- Link to signup screen for new teacher accounts

### 2. Headmaster Login Screen (`headmaster_login_screen.dart`)

**Path:** `/headmaster-login`

**Features:**

- Specialized theme with blue color scheme (#155EEF)
- Admin-focused messaging: "Administration Portal"
- Highlights key capabilities:
  - Admin access
  - User management
  - Full system control

**Form Fields:**

- Email Address (required)
- Password (required, with visibility toggle)

**Behavior:**

- Auto-redirects to dashboard if already logged in
- Shows admin-specific error message if non-headmaster tries to login
- Back button returns to role selection

### 3. Teacher Login Screen (`teacher_login_screen.dart`)

**Path:** `/teacher-login`

**Features:**

- Specialized theme with green color scheme (#10B981)
- Teacher-focused messaging: "Teacher Portal"
- Highlights key capabilities:
  - Result uploads
  - Class management
  - Student records

**Form Fields:**

- Email Address (required)
- Password (required, with visibility toggle)

**Behavior:**

- Auto-redirects to dashboard if already logged in
- Shows helpful error message if account doesn't exist: "Your account has not been created yet. Ask your headmaster to create an account for you."
- Back button returns to role selection

---

## Navigation Routes

### Authentication Routes

| Route | Screen | Purpose |
|-------|--------|---------|
| `/` | SplashScreen | Initial app load |
| `/login` | LoginScreen | Legacy login (still available) |
| `/role-selection` | RoleSelectionScreen | Choose headmaster or teacher |
| `/headmaster-login` | HeadmasterLoginScreen | Headmaster authentication |
| `/teacher-login` | TeacherLoginScreen | Teacher authentication |
| `/signup` | SignUpScreen | New teacher account creation |

### Dashboard & Main Routes

| Route | Screen | Purpose |
|-------|--------|---------|
| `/dashboard` | DashboardScreen | Main workspace |
| `/manage` | ManagementScreen | Manage teachers/students |
| `/results` | ResultsScreen | View/manage results |
| `/analytics` | AnalyticsScreen | Performance analytics |
| And more... | ... | ... |

---

## Implementation Details

### Modified Files

#### 1. **App Router** (`lib/core/router/app_router.dart`)

- Added imports for new screens
- Added three new routes:
  - `/role-selection`
  - `/headmaster-login`
  - `/teacher-login`
- Maintained backward compatibility with `/login`

#### 2. **Splash Screen** (`lib/features/student_management/presentation/screens/splash_screen.dart`)

- Changed redirect destination from `/login` to `/role-selection`
- Users now start at role selection instead of generic login

#### 3. **New Screen Files**

Three new screen files created:

1. **`role_selection_screen.dart`**
   - StatelessWidget (no state needed)
   - Shows two role cards with clear descriptions
   - Routes to appropriate login based on selection

2. **`headmaster_login_screen.dart`**
   - ConsumerStatefulWidget (uses Riverpod)
   - Extends `SchoolAdminController.signInWithEmailAndPassword()`
   - Blue theme (#155EEF) with admin branding
   - Shows admin-specific messages

3. **`teacher_login_screen.dart`**
   - ConsumerStatefulWidget (uses Riverpod)
   - Extends `SchoolAdminController.signInWithEmailAndPassword()`
   - Green theme (#10B981) with teacher branding
   - Shows helpful guidance messages

### Shared Authentication Logic

Both login screens use the same authentication backend:

- `SchoolAdminController.signInWithEmailAndPassword()`
- `Supabase` for credentials verification
- JWT token management
- Session persistence

---

## Security Considerations

### Authentication

- ✅ Email/password validation on both screens
- ✅ Credentials verified against Supabase/Backend
- ✅ Account lockout after failed attempts (backend)
- ✅ Secure token storage (flutter_secure_storage)
- ✅ Session management

### Access Control

- ✅ Headmaster login validates admin role
- ✅ Teacher login accessible only after headmaster creates account
- ✅ Role-based routing in dashboard
- ✅ Separate visual/functional experiences per role

### Best Practices

- ✅ No hardcoded credentials
- ✅ Passwords hidden by default
- ✅ Form validation before submission
- ✅ Clear error messages (without exposing system details)
- ✅ Auto-logout on 15-minute inactivity (backend)
- ✅ 2FA support (if configured)

---

## User Experience Improvements

### For Headmasters

1. Clear "Administration Portal" branding
2. Reminders of admin capabilities
3. Dedicated admin-only error messages
4. Quick navigation to admin functions

### For Teachers

1. Teacher-specific UI and messaging
2. Guidance if account not created yet
3. Clear button label matching their role
4. Focus on teaching-related tasks

### For All Users

1. Choice between roles on first screen
2. Back buttons to role selection
3. Responsive design (mobile/desktop)
4. Consistent theming with app brand

---

## Testing Checklist

### Login Flow

- [ ] Splash screen → Role selection
- [ ] Role selection → Headmaster login
- [ ] Role selection → Teacher login
- [ ] Both logins → Dashboard (on success)
- [ ] Invalid credentials → Error message
- [ ] Already logged in → Auto-redirect to dashboard

### Error Handling

- [ ] Non-headmaster trying headmaster login → Error
- [ ] Non-existent teacher account → Error
- [ ] Empty fields → Validation message
- [ ] Invalid email format → Validation message
- [ ] Password visibility toggle works

### Navigation

- [ ] Back button from headmaster login works
- [ ] Back button from teacher login works
- [ ] Sign up link from role selection works
- [ ] Auto-redirect on logout returns to role selection

---

## Future Enhancements

1. **Remember me functionality** - Save email on selected device
2. **Single sign-on (SSO)** - Integration with school LDAP/AD
3. **Biometric authentication** - Fingerprint/Face ID support
4. **Risk-based authentication** - Extra verification for suspicious logins
5. **Login analytics** - Track which portals are used most
6. **Account recovery** - Secure password reset flows
7. **Multi-factor authentication** - SMS/Email OTP options
8. **Audit logging** - Log all login attempts with IP/device info

---

## FAQ

**Q: Why two separate login screens instead of one?**  
A: The separate screens provide role-specific guidance, themes, and error messages, making the experience clearer for each user type.

**Q: Can headmasters use the teacher login?**  
A: No, the teacher login is only for teacher accounts. Headmasters must use the headmaster login portal.

**Q: What if a teacher forgets their password?**  
A: They should contact their headmaster. Password reset functionality can be added via the backend.

**Q: How are teacher accounts created?**  
A: Only headmasters can create teacher accounts. They access Teacher Management → "Add Teacher" and provide the teacher's name, email, and subject/class assignments.

**Q: Is there a student login?**  
A: No, students don't have direct system access. Their data is managed by teachers and headmasters.

---

## Related Documentation

- [Backend Reports Integration Guide](BACKEND_REPORTS_INTEGRATION.md)
- [Security Checklist](SECURITY_CHECKLIST.md)
- [System Improvements](SYSTEM_IMPROVEMENTS.md)
